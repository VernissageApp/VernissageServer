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
    private struct MigrationOutbox: Sendable {
        var followItemIds: [Int64] = []
        var moveItemIds: [Int64] = []
    }

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

        // The migration outbox is durable, so repeating the same request must not create
        // another set of ActivityPub activities. Re-enqueue any due items instead.
        if sourceUser.$movedTo.id == targetUserId {
            try await context.services.accountMigrationActivityPubService.dispatchPending(on: context)
            return
        }

        let outbox = try await context.db.transaction { transaction in
            let transactionContext = context.with(transaction: transaction)
            sourceUser.$movedTo.id = targetUserId
            try await sourceUser.save(on: transaction)

            return try await self.prepareMigration(from: sourceUser,
                                                   to: targetUser,
                                                   includeMoveDeliveries: true,
                                                   on: transactionContext)
        }

        await context.services.accountMigrationActivityPubService.dispatch(followItemIds: outbox.followItemIds,
                                                                           moveItemIds: outbox.moveItemIds,
                                                                           on: context)
    }

    func unmove(sourceUser: User, on context: ExecutionContext) async throws {
        guard sourceUser.isLocal else {
            throw AccountMigrationError.onlyLocalAccountsCanBeMoved
        }

        let sourceUserId = try sourceUser.requireID()
        try await context.db.transaction { transaction in
            let transactionContext = context.with(transaction: transaction)
            sourceUser.$movedTo.id = nil
            try await sourceUser.save(on: transaction)
            try await context.services.accountMigrationActivityPubService.cancel(sourceUserId: sourceUserId,
                                                                                  on: transactionContext)
        }
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

        let outbox = try await context.db.transaction { transaction in
            let transactionContext = context.with(transaction: transaction)
            sourceUser.$movedTo.id = targetUserId
            try await sourceUser.save(on: transaction)

            return try await self.prepareMigration(from: sourceUser,
                                                   to: targetUser,
                                                   includeMoveDeliveries: false,
                                                   on: transactionContext)
        }

        await context.services.accountMigrationActivityPubService.dispatch(followItemIds: outbox.followItemIds,
                                                                           moveItemIds: [],
                                                                           on: context)
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

        let activityPubDownloadUserService = context.services.activityPubDownloadUserService
        if let targetUser = try await activityPubDownloadUserService.downloadIfNeeded(activityPubProfile: targetActivityPubProfile, on: context) {
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
                let activityPubDownloadUserService = context.services.activityPubDownloadUserService
                return await activityPubDownloadUserService.resolveActivityPubProfile(userName: normalizedAccount, on: context)
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

        let activityPubDownloadUserService = context.services.activityPubDownloadUserService
        return try await activityPubDownloadUserService.refreshRemoteUser(activityPubProfile: activityPubProfile, on: context)
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

        let activityPubDownloadUserService = context.services.activityPubDownloadUserService
        let remoteTargetPerson = try await activityPubDownloadUserService.downloadPerson(activityPubProfile: targetUser.activityPubProfile, on: context)
        guard let alsoKnownAs = remoteTargetPerson.alsoKnownAs else {
            return false
        }

        return alsoKnownAs.contains {
            $0.compare(sourceActivityPubProfile, options: .caseInsensitive) == .orderedSame
        }
    }

    private func prepareMigration(from sourceUser: User,
                                  to targetUser: User,
                                  includeMoveDeliveries: Bool,
                                  on context: ExecutionContext) async throws -> MigrationOutbox {
        let sourceUserId = try sourceUser.requireID()
        let targetUserId = try targetUser.requireID()
        let usersService = context.services.usersService
        let snowflakeService = context.services.snowflakeService
        var outbox = MigrationOutbox()

        let followEventId = snowflakeService.generate()
        let followEvent = MigrationFollowActivityPubEvent(id: followEventId,
                                                          sourceUserId: sourceUserId,
                                                          targetUserId: targetUserId,
                                                          source: sourceUser.activityPubProfile,
                                                          target: targetUser.activityPubProfile)
        try await followEvent.save(on: context.db)

        let follows = try await Follow.query(on: context.db)
            .filter(\.$target.$id == sourceUserId)
            .filter(\.$approved == true)
            .with(\.$source)
            .all()
            .filter { $0.source.isLocal }

        for follow in follows {
            let localFollower = follow.source
            let localFollowerId = try localFollower.requireID()

            let existingFollow = try await Follow.query(on: context.db)
                .filter(\.$source.$id == localFollowerId)
                .filter(\.$target.$id == targetUserId)
                .first()

            if existingFollow == nil {
                let newFollowId = snowflakeService.generate()
                let approved = targetUser.isLocal && targetUser.manuallyApprovesFollowers == false
                let newFollow = Follow(id: newFollowId,
                                       sourceId: localFollowerId,
                                       targetId: targetUserId,
                                       approved: approved,
                                       activityId: nil)
                try await newFollow.save(on: context.db)

                if targetUser.isLocal == false {
                    let itemId = snowflakeService.generate()
                    let item = MigrationFollowActivityPubEventItem(id: itemId,
                                                                   migrationFollowActivityPubEventId: followEventId,
                                                                   actorUserId: localFollowerId,
                                                                   type: .follow,
                                                                   source: localFollower.activityPubProfile,
                                                                   target: targetUser.activityPubProfile,
                                                                   inbox: targetUser.userInbox ?? targetUser.sharedInbox ?? "",
                                                                   activityId: newFollowId)
                    try await item.save(on: context.db)
                    outbox.followItemIds.append(itemId)
                }
            }

            let unfollowId = try follow.requireID()
            try await follow.delete(on: context.db)

            if sourceUser.isLocal == false {
                let itemId = snowflakeService.generate()
                let item = MigrationFollowActivityPubEventItem(id: itemId,
                                                               migrationFollowActivityPubEventId: followEventId,
                                                               actorUserId: localFollowerId,
                                                               type: .unfollow,
                                                               source: localFollower.activityPubProfile,
                                                               target: sourceUser.activityPubProfile,
                                                               inbox: sourceUser.userInbox ?? sourceUser.sharedInbox ?? "",
                                                               activityId: unfollowId)
                try await item.save(on: context.db)
                outbox.followItemIds.append(itemId)
            }

            try await usersService.updateFollowCount(for: localFollowerId, on: context.db)
        }

        if outbox.followItemIds.isEmpty {
            followEvent.result = .finished
            followEvent.startedAt = Date()
            followEvent.endedAt = Date()
            try await followEvent.save(on: context.db)
        }

        if includeMoveDeliveries {
            let moveEventId = snowflakeService.generate()
            let moveEvent = MigrationMoveActivityPubEvent(id: moveEventId,
                                                          sourceUserId: sourceUserId,
                                                          targetUserId: targetUserId,
                                                          source: sourceUser.activityPubProfile,
                                                          target: targetUser.activityPubProfile)
            try await moveEvent.save(on: context.db)

            let remoteFollows = try await Follow.query(on: context.db)
                .filter(\.$target.$id == sourceUserId)
                .filter(\.$approved == true)
                .with(\.$source)
                .all()
                .filter { $0.source.isLocal == false }

            let inboxes = Set(remoteFollows.map { $0.source.sharedInbox ?? $0.source.userInbox ?? "" })
            for inbox in inboxes {
                let itemId = snowflakeService.generate()
                let item = MigrationMoveActivityPubEventItem(id: itemId,
                                                             migrationMoveActivityPubEventId: moveEventId,
                                                             inbox: inbox)
                try await item.save(on: context.db)
                outbox.moveItemIds.append(itemId)
            }

            if outbox.moveItemIds.isEmpty {
                moveEvent.result = .finished
                moveEvent.startedAt = Date()
                moveEvent.endedAt = Date()
                try await moveEvent.save(on: context.db)
            }
        }

        try await usersService.updateFollowCount(for: sourceUserId, on: context.db)
        try await usersService.updateFollowCount(for: targetUserId, on: context.db)

        return outbox
    }
}
