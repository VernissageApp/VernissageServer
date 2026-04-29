//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension Application.Services {
    struct AccountMigrationServiceKey: StorageKey {
        typealias Value = AccountMigrationServiceType
    }

    var accountMigrationService: AccountMigrationServiceType {
        get {
            self.application.storage[AccountMigrationServiceKey.self] ?? AccountMigrationService()
        }
        nonmutating set {
            self.application.storage[AccountMigrationServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol AccountMigrationServiceType: Sendable {
    /// Starts account migration for a local source user to a target account.
    /// - Parameters:
    ///   - sourceUser: User account that is being moved from.
    ///   - targetAccount: Target account identifier (local/remote account or ActivityPub profile).
    ///   - context: Execution context with database and services.
    /// - Throws: ``AccountMigrationError`` or underlying database/network errors.
    func move(sourceUser: User, to targetAccount: String, on context: ExecutionContext) async throws

    /// Reverts account migration for a local source user by clearing `movedTo`.
    /// - Parameters:
    ///   - sourceUser: User account that is being moved from.
    ///   - context: Execution context with database and services.
    /// - Throws: ``AccountMigrationError`` or underlying database/network errors.
    func unmove(sourceUser: User, on context: ExecutionContext) async throws
    
    /// Processes incoming ActivityPub `Move` activity from shared/user inbox.
    /// - Parameters:
    ///   - activityPubRequest: Parsed ActivityPub request containing `Move` activity.
    ///   - context: Execution context with database and services.
    /// - Throws: Underlying database/network errors.
    func processMove(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws
}

final class AccountMigrationService: AccountMigrationServiceType {
    func move(sourceUser: User, to targetAccount: String, on context: ExecutionContext) async throws {
        guard sourceUser.isLocal else {
            throw AccountMigrationError.onlyLocalAccountsCanBeMoved
        }
        
        let targetUser = try await self.resolveTargetUser(from: sourceUser, account: targetAccount, on: context)
        let sourceUserId = try sourceUser.requireID()
        let targetUserId = try targetUser.requireID()
        
        guard sourceUserId != targetUserId else {
            throw AccountMigrationError.cannotMoveToTheSameAccount
        }
        
        let isAlias = try await self.targetHasAlias(sourceActivityPubProfile: sourceUser.activityPubProfile,
                                                    targetUser: targetUser,
                                                    on: context)
        guard isAlias else {
            throw AccountMigrationError.targetAccountIsNotAlias
        }
        
        sourceUser.$movedTo.id = targetUserId
        try await sourceUser.save(on: context.db)
        
        try await self.migrateLocalFollowers(from: sourceUser, to: targetUser, on: context)
        try await self.sendMoveToRemoteFollowers(from: sourceUser, targetActivityPubProfile: targetUser.activityPubProfile, on: context)
    }

    func unmove(sourceUser: User, on context: ExecutionContext) async throws {
        guard sourceUser.isLocal else {
            throw AccountMigrationError.onlyLocalAccountsCanBeMoved
        }

        sourceUser.$movedTo.id = nil
        try await sourceUser.save(on: context.db)
    }
    
    func processMove(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let activity = activityPubRequest.activity
        
        guard let sourceActivityPubProfile = activity.actor.actorIds().first else {
            context.logger.warning("Cannot process Move activity '\(activity.id)' because actor is missing.")
            return
        }
        
        guard let targetActivityPubProfile = activity.target?.actorIds().first else {
            context.logger.warning("Cannot process Move activity '\(activity.id)' because target is missing.")
            return
        }
        
        guard sourceActivityPubProfile.compare(targetActivityPubProfile, options: .caseInsensitive) != .orderedSame else {
            context.logger.warning("Cannot process Move activity '\(activity.id)' because source and target are equal.")
            return
        }
        
        let objects = activity.object.objects()
        if let objectActorId = objects.first?.id,
           objectActorId.compare(sourceActivityPubProfile, options: .caseInsensitive) != .orderedSame {
            context.logger.warning("Cannot process Move activity '\(activity.id)' because object '\(objectActorId)' does not match actor '\(sourceActivityPubProfile)'.")
            return
        }
        
        guard let sourceUser = try await self.getOrDownloadUser(activityPubProfile: sourceActivityPubProfile, on: context) else {
            context.logger.warning("Cannot process Move activity '\(activity.id)' because source actor cannot be downloaded: '\(sourceActivityPubProfile)'.")
            return
        }
        
        guard let targetUser = try await self.getOrDownloadUser(activityPubProfile: targetActivityPubProfile, on: context) else {
            context.logger.warning("Cannot process Move activity '\(activity.id)' because target actor cannot be downloaded: '\(targetActivityPubProfile)'.")
            return
        }
        
        let isAlias = try await self.targetHasAlias(sourceActivityPubProfile: sourceActivityPubProfile,
                                                    targetUser: targetUser,
                                                    on: context)
        guard isAlias else {
            context.logger.warning("Cannot process Move activity '\(activity.id)' because target actor '\(targetActivityPubProfile)' is not an alias of source actor '\(sourceActivityPubProfile)'.")
            return
        }

        let sourceMovedToId = sourceUser.$movedTo.id
        let targetUserId = try targetUser.requireID()

        guard sourceMovedToId == targetUserId else {
            context.logger.warning("Cannot process Move activity '\(activity.id)' because source actor '\(sourceActivityPubProfile)' does not point movedTo to target actor '\(targetActivityPubProfile)'.")
            return
        }
        
        sourceUser.$movedTo.id = targetUserId
        try await sourceUser.save(on: context.db)
        
        try await self.migrateLocalFollowers(from: sourceUser, to: targetUser, on: context)
    }
    
    private func resolveTargetUser(from sourceUser: User, account: String, on context: ExecutionContext) async throws -> User {
        guard let targetActivityPubProfile = try await self.resolveTargetActivityPubProfile(account: account, on: context) else {
            throw AccountMigrationError.targetAccountNotFound
        }
        
        guard sourceUser.activityPubProfile.compare(targetActivityPubProfile, options: .caseInsensitive) != .orderedSame else {
            throw AccountMigrationError.cannotMoveToTheSameAccount
        }
        
        if let targetUser = try await context.services.usersService.get(activityPubProfile: targetActivityPubProfile, on: context.db) {
            return targetUser
        }
        
        if let targetUser = try await context.services.searchService.downloadRemoteUser(activityPubProfile: targetActivityPubProfile, on: context) {
            return targetUser
        }
        
        throw AccountMigrationError.targetAccountNotFound
    }
    
    private func resolveTargetActivityPubProfile(account: String, on context: ExecutionContext) async throws -> String? {
        let trimmedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAccount.isEmpty else {
            return nil
        }
        
        if trimmedAccount.hasPrefix("http://") || trimmedAccount.hasPrefix("https://") {
            return trimmedAccount
        }
        
        let normalizedAccount = trimmedAccount.deletingPrefix("@")
        guard !normalizedAccount.isEmpty else {
            return nil
        }
        
        let usersService = context.services.usersService
        if normalizedAccount.contains("@") {
            let components = normalizedAccount.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
            guard components.count == 2 else {
                return nil
            }
            
            let userName = String(components[0])
            let domain = String(components[1])
            
            if self.isLocalDomain(domain, on: context) {
                return try await usersService.get(userName: userName.uppercased(), on: context.db)?.activityPubProfile
            } else {
                return await context.services.searchService.getRemoteActivityPubProfile(userName: normalizedAccount, on: context)
            }
        }
        
        return try await usersService.get(userName: normalizedAccount.uppercased(), on: context.db)?.activityPubProfile
    }

    private func isLocalDomain(_ domain: String, on context: ExecutionContext) -> Bool {
        let localDomain = context.settings.cached?.domain ?? ""
        if domain.compare(localDomain, options: .caseInsensitive) == .orderedSame {
            return true
        }
        
        let baseAddress = context.settings.cached?.baseAddress ?? ""
        guard let url = URL(string: baseAddress), let host = url.host else {
            return false
        }
        
        if domain.compare(host, options: .caseInsensitive) == .orderedSame {
            return true
        }
        
        if let port = url.port {
            let hostWithPort = "\(host):\(port)"
            if domain.compare(hostWithPort, options: .caseInsensitive) == .orderedSame {
                return true
            }
        }
        
        return false
    }
    
    private func getOrDownloadUser(activityPubProfile: String, on context: ExecutionContext) async throws -> User? {
        if let user = try await context.services.usersService.get(activityPubProfile: activityPubProfile, on: context.db),
           user.isLocal {
            return user
        }
        
        return try await context.services.searchService.refreshRemoteUser(activityPubProfile: activityPubProfile, on: context)
    }
    
    private func targetHasAlias(sourceActivityPubProfile: String, targetUser: User, on context: ExecutionContext) async throws -> Bool {
        if targetUser.isLocal {
            let targetUserId = try targetUser.requireID()
            let aliases = try await UserAlias.query(on: context.db)
                .filter(\.$user.$id == targetUserId)
                .all()
            
            return aliases.contains {
                $0.activityPubProfile.compare(sourceActivityPubProfile, options: .caseInsensitive) == .orderedSame
            }
        }
        
        let remoteTargetPerson = try await self.downloadPerson(activityPubProfile: targetUser.activityPubProfile, on: context)
        guard let alsoKnownAs = remoteTargetPerson.alsoKnownAs else {
            return false
        }
        
        return alsoKnownAs.contains {
            $0.compare(sourceActivityPubProfile, options: .caseInsensitive) == .orderedSame
        }
    }
    
    private func downloadPerson(activityPubProfile: String, on context: ExecutionContext) async throws -> PersonDto {
        let usersService = context.services.usersService
        guard let defaultSystemUser = try await usersService.getDefaultSystemUser(on: context.db) else {
            throw ActivityPubError.missingInstanceAdminAccount
        }
        
        guard let privateKey = defaultSystemUser.privateKey else {
            throw ActivityPubError.missingInstanceAdminPrivateKey
        }
        
        guard let activityPubProfileUrl = URL(string: activityPubProfile) else {
            throw ActivityPubError.unrecognizedActivityPubProfileUrl
        }
        
        let activityPubClient = ActivityPubClient(privatePemKey: privateKey,
                                                  userAgent: Constants.userAgent,
                                                  host: activityPubProfileUrl.host)
        return try await activityPubClient.person(id: activityPubProfile, activityPubProfile: defaultSystemUser.activityPubProfile)
    }
    
    private func migrateLocalFollowers(from sourceUser: User, to targetUser: User, on context: ExecutionContext) async throws {
        let sourceUserId = try sourceUser.requireID()
        let targetUserId = try targetUser.requireID()
        let followsService = context.services.followsService
        let usersService = context.services.usersService
        
        let follows = try await Follow.query(on: context.db)
            .filter(\.$target.$id == sourceUserId)
            .filter(\.$approved == true)
            .with(\.$source)
            .all()
            .filter { $0.source.isLocal }
        
        for follow in follows {
            do {
                let localFollower = follow.source
                let localFollowerId = try localFollower.requireID()
                
                let existingFollow = try await followsService.get(sourceId: localFollowerId, targetId: targetUserId, on: context.db)
                var followIdToDispatch: Int64? = nil
                
                if existingFollow == nil {
                    let approved = targetUser.isLocal && targetUser.manuallyApprovesFollowers == false
                    let followId = try await followsService.follow(sourceId: localFollowerId,
                                                                   targetId: targetUserId,
                                                                   approved: approved,
                                                                   activityId: nil,
                                                                   on: context)
                    
                    if targetUser.isLocal == false {
                        followIdToDispatch = followId
                    }
                }
                
                let unfollowId = try await followsService.unfollow(sourceId: localFollowerId,
                                                                   targetId: sourceUserId,
                                                                   on: context)
                
                if let followIdToDispatch, let privateKey = localFollower.privateKey {
                    try await self.dispatchFollowRequest(type: .follow,
                                                         source: localFollower.activityPubProfile,
                                                         target: targetUser.activityPubProfile,
                                                         inbox: targetUser.userInbox ?? targetUser.sharedInbox,
                                                         withId: followIdToDispatch,
                                                         privateKey: privateKey,
                                                         on: context)
                }
                
                if sourceUser.isLocal == false, let unfollowId, let privateKey = localFollower.privateKey {
                    try await self.dispatchFollowRequest(type: .unfollow,
                                                         source: localFollower.activityPubProfile,
                                                         target: sourceUser.activityPubProfile,
                                                         inbox: sourceUser.userInbox ?? sourceUser.sharedInbox,
                                                         withId: unfollowId,
                                                         privateKey: privateKey,
                                                         on: context)
                }
                
                try await usersService.updateFollowCount(for: localFollowerId, on: context.db)
            } catch {
                await context.logger.store("Cannot migrate follow '\(follow.stringId() ?? "")' during account migration from '\(sourceUser.activityPubProfile)' to '\(targetUser.activityPubProfile)'.", error, on: context.application)
            }
        }
        
        try await usersService.updateFollowCount(for: sourceUserId, on: context.db)
        try await usersService.updateFollowCount(for: targetUserId, on: context.db)
    }
    
    private func sendMoveToRemoteFollowers(from sourceUser: User, targetActivityPubProfile: String, on context: ExecutionContext) async throws {
        guard sourceUser.isLocal else {
            return
        }
        
        let sourceUserId = try sourceUser.requireID()
        guard let privateKey = sourceUser.privateKey else {
            throw ActivityPubError.privateKeyNotExists(sourceUser.activityPubProfile)
        }
        
        let follows = try await Follow.query(on: context.db)
            .filter(\.$target.$id == sourceUserId)
            .filter(\.$approved == true)
            .with(\.$source)
            .all()
            .filter { $0.source.isLocal == false }
        
        for follow in follows {
            let remoteFollower = follow.source
            let eventId = context.services.snowflakeService.generate()
            
            try await self.dispatchFollowRequest(type: .move,
                                                 source: sourceUser.activityPubProfile,
                                                 target: targetActivityPubProfile,
                                                 inbox: remoteFollower.userInbox ?? remoteFollower.sharedInbox,
                                                 withId: eventId,
                                                 privateKey: privateKey,
                                                 on: context)
        }
    }
    
    private func dispatchFollowRequest(type: ActivityPubFollowRequestDto.FollowRequestType,
                                       source: String,
                                       target: String,
                                       inbox: String?,
                                       withId id: Int64,
                                       privateKey: String,
                                       on context: ExecutionContext) async throws {
        guard let inbox, let inboxUrl = URL(string: inbox) else {
            return
        }
        
        let activityPubFollowRequestDto = ActivityPubFollowRequestDto(type: type,
                                                                      source: source,
                                                                      target: target,
                                                                      sharedInbox: inboxUrl,
                                                                      id: id,
                                                                      privateKey: privateKey)
        
        try await context
            .queues(.apFollowRequester)
            .dispatch(ActivityPubFollowRequesterJob.self, activityPubFollowRequestDto)
    }
}
