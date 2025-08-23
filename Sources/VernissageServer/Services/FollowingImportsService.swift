//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct FollowingImportsServiceKey: StorageKey {
        typealias Value = FollowingImportsServiceType
    }

    var followingImportsService: FollowingImportsServiceType {
        get {
            self.application.storage[FollowingImportsServiceKey.self] ?? FollowingImportsService()
        }
        nonmutating set {
            self.application.storage[FollowingImportsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol FollowingImportsServiceType: Sendable {
    /// Retrieves a following import by its unique identifier, including all import items.
    ///
    /// - Parameters:
    ///   - id: The unique identifier of the following import.
    ///   - database: The database connection to use.
    /// - Returns: The following import if found, or nil if not found.
    /// - Throws: An error if the database query fails.
    func get(by id: Int64, on database: Database) async throws -> FollowingImport?

    /// Processes and executes the following import for the given identifier, sending follow requests and updating statuses.
    ///
    /// - Parameters:
    ///   - id: The unique identifier of the following import.
    ///   - context: The execution context providing access to services, settings, and the database.
    /// - Throws: An error if the import processing fails.
    func run(for id: Int64, on context: ExecutionContext) async throws
}

/// A service for managing following imports in the system.
final class FollowingImportsService: FollowingImportsServiceType {
    func get(by id: Int64, on database: Database) async throws -> FollowingImport? {
        return try await FollowingImport.query(on: database)
            .filter(\.$id == id)
            .with(\.$followingImportItems)
            .first()
    }
    
    func run(for id: Int64, on context: ExecutionContext) async throws {
        let notificationsService = context.application.services.notificationsService
        let followsService = context.application.services.followsService
        let usersService = context.application.services.usersService
        
        let followingImport = try await self.get(by: id, on: context.db)
        
        guard let followingImport else {
            context.logger.info("Cannot find following import (id: \(id)), skipping.")
            return
        }
        
        guard followingImport.status == .new else {
            context.logger.info("Following import (id: \(id)) is not in a new status, skipping.")
            return
        }
        
        let sourceUserId = followingImport.$user.id
        guard let sourceUser = try await usersService.get(id: sourceUserId, on: context.db) else {
            context.logger.info("Cannot find source user data (id: \(sourceUserId)), skipping.")
            return
        }
        
        // Set following import as processing.
        followingImport.status = .processing
        followingImport.startedAt = Date()
        try await followingImport.save(on: context.db)
        
        // Sending follow request to all accounts from import file.
        for followingImportItem in followingImport.followingImportItems {
            do {
                guard followingImportItem.status == .notProcessed else {
                    continue
                }
                
                // Set start processing date.
                followingImportItem.startedAt = Date()
                try await followingImportItem.save(on: context.db)
                
                // Searching for the account from local database.
                guard let followedUser = try await self.getUser(by: followingImportItem.account, context: context) else {
                    context.logger.info("Account (userName: '\(followingImportItem.account)') cannot be downloaded from remote server.")
                    throw FollowImportError.accountNotFound
                }
                
                // Check if user is not already following imported usuer.
                let follow = try await followsService.get(sourceId: sourceUserId, targetId: followedUser.requireID(), on: context.db)
                guard follow == nil else {
                    followingImportItem.status = .followed
                    followingImportItem.endedAt = Date()
                    try await followingImportItem.save(on: context.db)
                    
                    context.logger.info("Imporing account skipped, user name '\(sourceUser.userName)' already follows account: '\(followedUser.userName)'.")
                    continue
                }
                
                // Relationship is automatically approved only when user disabled manual aproving and is local.
                let approved = followedUser.isLocal && followedUser.manuallyApprovesFollowers == false
                
                // Save follow in local database.
                let followId = try await followsService.follow(sourceId: sourceUserId,
                                                               targetId: followedUser.requireID(),
                                                               approved: approved,
                                                               activityId: nil,
                                                               on: context)
                
                try await usersService.updateFollowCount(for: sourceUserId, on: context.db)
                try await usersService.updateFollowCount(for: followedUser.requireID(), on: context.db)
                
                // Send notification to user about follow.
                try await notificationsService.create(type: approved ? .follow : .followRequest,
                                                      to: followedUser,
                                                      by: sourceUserId,
                                                      statusId: nil,
                                                      mainStatusId: nil,
                                                      on: context)
                
                // If target user is from remote server, notify remote server about follow.
                if followedUser.isLocal == false {
                    guard let privateKey = sourceUser.privateKey else {
                        throw ActivityPubError.privateKeyNotExists(sourceUser.activityPubProfile)
                    }
                                
                    try await informRemote(on: context,
                                           type: .follow,
                                           source: sourceUser.activityPubProfile,
                                           target: followedUser.activityPubProfile,
                                           sharedInbox: followedUser.sharedInbox,
                                           withId: followId,
                                           privateKey: privateKey)
                }
                
                followingImportItem.status = approved ? .followed : .sent
                followingImportItem.endedAt = Date()
                try await followingImportItem.save(on: context.db)
            } catch {
                context.logger.info("Following imported account (userName: '\(followingImportItem.account)') failed. Error message '\(error)'.")

                followingImportItem.status = .error
                followingImportItem.endedAt = Date()
                followingImportItem.errorMessage = error.localizedDescription
                try? await followingImportItem.save(on: context.db)
            }
        }
        
        // Set following import as finished.
        followingImport.status = .finished
        followingImport.endedAt = Date()
        try await followingImport.save(on: context.db)
    }
    
    private func getUser(by account: String, context: ExecutionContext) async throws -> User? {
        let userNameNormalized = account.uppercased()
        
        let userFromDb = try await User.query(on: context.db).group(.or) { userNameGroup in
            userNameGroup.filter(\.$userNameNormalized == userNameNormalized)
            userNameGroup.filter(\.$accountNormalized == userNameNormalized)
        }.first()
        
        if let userFromDb {
            return userFromDb
        }

        // Download profile from remote server.
        context.logger.info("Downloading account \(account) from remote server.")
        
        let searchService = context.application.services.searchService
        let remoteUser = try await searchService.downloadRemoteUser(userName: account, on: context)
        if let remoteUser {
            return remoteUser
        }
        
        return nil
    }
    
    private func informRemote(on context: ExecutionContext,
                              type: ActivityPubFollowRequestDto.FollowRequestType,
                              source: String,
                              target: String,
                              sharedInbox: String?,
                              withId id: Int64,
                              privateKey: String) async throws {
        guard let sharedInbox, let sharedInboxUrl = URL(string: sharedInbox) else {
            return
        }
        
        let activityPubFollowRequestDto = ActivityPubFollowRequestDto(type: type,
                                                                      source: source,
                                                                      target: target,
                                                                      sharedInbox: sharedInboxUrl,
                                                                      id: id,
                                                                      privateKey: privateKey)

        try await context
            .queues(.apFollowRequester)
            .dispatch(ActivityPubFollowRequesterJob.self, activityPubFollowRequestDto)
    }
}
