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
    func validateSignature(on context: QueueContext, activityPubRequest: ActivityPubRequestDto) async throws
    func validateDomain(on context: QueueContext, activityPubRequest: ActivityPubRequestDto) throws

    func delete(on context: QueueContext, activity: ActivityDto) throws
    func follow(on context: QueueContext, activity: ActivityDto) async throws
    func accept(on context: QueueContext, activity: ActivityDto) throws
    func undo(on context: QueueContext, activity: ActivityDto) async throws
}

final class ActivityPubService: ActivityPubServiceType {
    /// Validate signature.
    public func validateSignature(on context: QueueContext, activityPubRequest: ActivityPubRequestDto) async throws {
        let searchService = context.application.services.searchService
        let cryptoService = context.application.services.cryptoService
        
        // Check if request is not old one.
        try self.verifyTimeWindow(activityPubRequest: activityPubRequest)
        
        // Get headers stored as Data.
        let generatedSignatureData = try self.generateSignatureData(activityPubRequest: activityPubRequest)
        
        // Get signature from header (decoded base64 as Data).
        let signatureData = try self.getSignatureData(activityPubRequest: activityPubRequest)
        
        // Get actor profile URL from header.
        let actorId = try self.getSignatureActor(activityPubRequest: activityPubRequest)
                
        // Download profile from remote server.
        guard let user = try await searchService.downloadRemoteUser(profileUrl: actorId, on: context) else {
            throw ActivityPubError.userNotExistsInDatabase(actorId)
        }
        
        guard let publicKey = user.publicKey else {
            throw ActivityPubError.privateKeyNotExists(actorId)
        }
                
        // Verify signature with actor's public key.
        let isValid = try cryptoService.verifySignature(publicKeyPem: publicKey, signatureData: signatureData, digest: generatedSignatureData)
        if !isValid {
            throw ActivityPubError.signatureIsNotValid
        }
    }
    
    // TODO: validate domain.
    public func validateDomain(on context: QueueContext, activityPubRequest: ActivityPubRequestDto) throws {
    }
    
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
                context.logger.warning("Undo of '\(activityObject.type)' action is not supported")
            }
        case .multiple(let activityObjects):
            for activityObject in activityObjects {
                switch activityObject.type {
                case .follow:
                    try await self.unfollow(sourceComplexActor: activity.actor, activityPubObject: activityObject, on: context)
                default:
                    context.logger.warning("Undo of '\(activityObject.type)' action is not supported")
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
        try await usersService.updateFollowCount(on: context.application.db, for: targetUser.requireID())
    }
    
    private func follow(sourceProfileUrl: String, targetProfileUrl: String, on context: QueueContext) async throws {
        context.logger.info("Following account: '\(targetProfileUrl)' by account '\(sourceProfileUrl)' (from remote server).")

        let searchService = context.application.services.searchService
        let followsService = context.application.services.followsService
        let usersService = context.application.services.usersService

        // Download profile from remote server.
        context.logger.info("Downloading account \(sourceProfileUrl) from remote server.")

        let remoteUser = try await searchService.downloadRemoteUser(profileUrl: sourceProfileUrl, on: context)
        guard let remoteUser else {
            context.logger.warning("Account '\(sourceProfileUrl)' cannot be downloaded from remote server.")
            return
        }
                
        let targetUser = try await usersService.get(on: context.application.db, activityPubProfile: targetProfileUrl)
        guard let targetUser else {
            context.logger.warning("Cannot find local user '\(targetProfileUrl)'.")
            return
        }
        
        try await followsService.follow(on: context.application.db, sourceId: remoteUser.requireID(), targetId: targetUser.requireID(), approved: true)
        try await usersService.updateFollowCount(on: context.application.db, for: targetUser.requireID())
    }
    
    private func getSignatureData(activityPubRequest: ActivityPubRequestDto) throws -> Data {
        guard let signatureHeader = activityPubRequest.headers.keys.first(where: { $0.lowercased() == "signature" }),
              let signatureHeaderValue = activityPubRequest.headers[signatureHeader] else {
            throw ActivityPubError.missingSignatureHeader
        }
                
        let signatureRegex = #/signature="(?<signature>[^"]*)"/#
        
        let signatureMatch = signatureHeaderValue.firstMatch(of: signatureRegex)
        guard let signature = signatureMatch?.signature else {
            throw ActivityPubError.missingSignatureInHeader
        }

        // Decode signature from Base64 into plain Data.
        guard let signatureData = Data(base64Encoded: String(signature)) else {
            throw ActivityPubError.missingSignatureInHeader
        }
        
        return signatureData
    }
    
    /// https://docs.joinmastodon.org/spec/security/#http-sign
    private func generateSignatureData(activityPubRequest: ActivityPubRequestDto) throws -> Data {
        guard let signatureHeader = activityPubRequest.headers.keys.first(where: { $0.lowercased() == "signature" }),
              let signatureHeaderValue = activityPubRequest.headers[signatureHeader] else {
            throw ActivityPubError.missingSignatureHeader
        }

        let headersRegex = #/headers="(?<headers>[^"]*)"/#
        
        let headersMatch = signatureHeaderValue.firstMatch(of: headersRegex)
        guard let headerNames = headersMatch?.headers.split(separator: " ") else {
            throw ActivityPubError.missingSignedHeadersList
        }
        
        var headersArray: [String] = []
        for headerName in headerNames {
            guard let signatureHeader = activityPubRequest.headers.keys.first(where: { $0.lowercased() == headerName.lowercased() }) else {
                throw ActivityPubError.missingSignedHeader(String(headerName))
            }
            
            if signatureHeader.lowercased() == "digest" {
                headersArray.append("\(headerName): SHA-256=\(activityPubRequest.bodyHash ?? "")")
            } else {
                headersArray.append("\(headerName): \(activityPubRequest.headers[signatureHeader] ?? "")")
            }
        }
        
        let headersString = headersArray.joined(separator: "\n")
        guard let data = headersString.data(using: .ascii) else {
            throw ActivityPubError.signatureDataNotCreated
        }
        
        return data
    }
    
    private func getSignatureActor(activityPubRequest: ActivityPubRequestDto) throws -> String {
        switch activityPubRequest.activity.actor {
        case .single(let activityPubActor):
            return activityPubActor.id
        case .multiple(_):
            throw ActivityPubError.singleActorIsSupportedInSigning
        }
    }
    
    private func verifyTimeWindow(activityPubRequest: ActivityPubRequestDto) throws {
        guard let dateHeader = activityPubRequest.headers.keys.first(where: { $0.lowercased() == "date" }),
              let dateHeaderValue = activityPubRequest.headers[dateHeader] else {
            throw ActivityPubError.missingDateHeader
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        guard let date = dateFormatter.date(from: dateHeaderValue) else {
            throw ActivityPubError.incorrectDateFormat(dateHeaderValue)
        }
        
        if date < Date.now.addingTimeInterval(-300) {
            throw ActivityPubError.badTimeWindow(dateHeaderValue)
        }
    }
}
