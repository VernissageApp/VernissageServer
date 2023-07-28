//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Queues
import ActivityPubKit

extension Application.Services {
    struct ActivityPubServiceKey: StorageKey {
        typealias Value = ActivityPubServiceType
    }

    var activityPubService: ActivityPubServiceType {
        get {
            self.application.storage[ActivityPubServiceKey.self] ?? ActivityPubService()
        }
        nonmutating set {
            self.application.storage[ActivityPubServiceKey.self] = newValue
        }
    }
}

protocol ActivityPubServiceType {
    func delete(on context: QueueContext, activity: ActivityDto) throws
    func follow(on context: QueueContext, activity: ActivityDto) async throws
    func accept(on context: QueueContext, activity: ActivityDto) throws
    func undo(on context: QueueContext, activity: ActivityDto) async throws
}

final class ActivityPubService: ActivityPubServiceType {
    public func delete(on context: QueueContext, activity: ActivityDto) throws {
    }
    
    public func follow(on context: QueueContext, activity: ActivityDto) async throws {
        switch activity.actor {
        case .single(let activityPubActor):
            
            switch activity.object {
            case .single(let objectActor):
                try await self.follow(sourceProfileUrl: activityPubActor.id, targetProfileUrl: objectActor.id, on: context)
            case .multiple(let objectActors):
                for objectActor in objectActors {
                    try await self.follow(sourceProfileUrl: activityPubActor.id, targetProfileUrl: objectActor.id, on: context)
                }
            }
            
        case .multiple(let activityPubActors):
            for activityPubActor in activityPubActors {
                switch activity.object {
                case .single(let objectActor):
                    try await self.follow(sourceProfileUrl: activityPubActor.id, targetProfileUrl: objectActor.id, on: context)
                case .multiple(let objectActors):
                    for objectActor in objectActors {
                        try await self.follow(sourceProfileUrl: activityPubActor.id, targetProfileUrl: objectActor.id, on: context)
                    }
                }
            }
        }
    }
    
    public func accept(on context: QueueContext, activity: ActivityDto) throws {
    }
    
    func undo(on context: QueueContext, activity: ActivityDto) async throws {
        switch activity.object {
        case .single(let activityObject):
            switch activityObject.type {
            case .follow:
                try await self.unfollow(sourceComplexActor: activity.actor, activityPubObject: activityObject, on: context)
            default:
                context.logger.warning("Unfollow of '\(activityObject.type)' action is not supported")
            }
        case .multiple(let activityObjects):
            for activityObject in activityObjects {
                switch activityObject.type {
                case .follow:
                    try await self.unfollow(sourceComplexActor: activity.actor, activityPubObject: activityObject, on: context)
                default:
                    context.logger.warning("Unfollow of '\(activityObject.type)' action is not supported")
                }
            }
        }
    }
    
    private func unfollow(sourceComplexActor: ComplexTypeDtos<BaseActorDto>, activityPubObject: BaseObjectDto, on context: QueueContext) async throws {
        switch sourceComplexActor {
        case .single(let sourceActor):
            try await self.unfollow(sourceActor: sourceActor, activityPubObject: activityPubObject, on: context)
        case .multiple(let sourceActors):
            for sourceActor in sourceActors {
                try await self.unfollow(sourceActor: sourceActor, activityPubObject: activityPubObject, on: context)
            }
        }
    }
    
    private func unfollow(sourceActor: BaseActorDto, activityPubObject: BaseObjectDto, on context: QueueContext) async throws {
        switch activityPubObject.object {
        case .single(let targetActor):
            print(targetActor.id)
            try await self.unfollow(sourceProfileUrl: sourceActor.id, targetProfileUrl: targetActor.id, on: context)
        case .multiple(let targetActors):
            for targetActor in targetActors {
                try await self.unfollow(sourceProfileUrl: sourceActor.id, targetProfileUrl: targetActor.id, on: context)
            }
        case .none:
            context.logger.warning("Object doesnt' contains correct actor entity.")
        }
    }
    
    private func unfollow(sourceProfileUrl: String, targetProfileUrl: String, on context: QueueContext) async throws {
        context.logger.info("Unfollowing account: '\(targetProfileUrl)' by account '\(sourceProfileUrl)' (from remote server).")

        let followsService = context.application.services.followsService
        let usersService = context.application.services.usersService
        
        let sourceUser = try await usersService.get(on: context.application.db, activityPubProfile: sourceProfileUrl)
        guard let sourceUser else {
            context.logger.warning("Cannot find user '\(sourceProfileUrl)' in local database.")
            return
        }
        
        let targetUser = try await usersService.get(on: context.application.db, activityPubProfile: targetProfileUrl)
        guard let targetUser else {
            context.logger.warning("Cannot find user '\(targetProfileUrl)' in local database.")
            return
        }
        
        try await followsService.unfollow(on: context.application.db, sourceId: sourceUser.requireID(), targetId: targetUser.requireID())
    }
    
    private func follow(sourceProfileUrl: String, targetProfileUrl: String, on context: QueueContext) async throws {
        context.logger.info("Following account: '\(targetProfileUrl)' by account '\(sourceProfileUrl)' (from remote server).")

        let searchService = context.application.services.searchService
        let followsService = context.application.services.followsService
        let usersService = context.application.services.usersService

        // Download profile from remote server.
        context.logger.info("Downloading account \(sourceProfileUrl) from remote server.")
        let result = await searchService.downloadRemoteUser(profileUrl: sourceProfileUrl, on: context)
        
        guard let remoteUser = result.users?.first else {
            context.logger.warning("Account '\(sourceProfileUrl)' cannot be downloaded from remote server.")
            return
        }
        
        guard let remoteUserId = remoteUser.id?.toId() else {
            context.logger.warning("Cannot cast remote user '\(sourceProfileUrl)' to Int64 id.")
            return
        }
        
        let targetUser = try await usersService.get(on: context.application.db, activityPubProfile: targetProfileUrl)
        guard let targetUser else {
            context.logger.warning("Cannot find local user '\(targetProfileUrl)'.")
            return
        }
        
        try await followsService.follow(on: context.application.db, sourceId: remoteUserId, targetId: targetUser.requireID(), approved: true)
    }
}
