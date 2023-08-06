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
    func validateAlgorith(on context: QueueContext, activityPubRequest: ActivityPubRequestDto) throws

    func delete(on context: QueueContext, activity: ActivityDto) throws
    func follow(on context: QueueContext, activity: ActivityDto) async throws
    func accept(on context: QueueContext, activity: ActivityDto) throws
    func undo(on context: QueueContext, activity: ActivityDto) async throws
}

final class ActivityPubService: ActivityPubServiceType {
    private enum SupportedAlgorithm: String {
        case rsaSha256 = "rsa-sha256"
    }
    
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
    
    public func validateAlgorith(on context: QueueContext, activityPubRequest: ActivityPubRequestDto) throws {
        guard let signatureHeader = activityPubRequest.headers.keys.first(where: { $0.lowercased() == "signature" }),
              let signatureHeaderValue = activityPubRequest.headers[signatureHeader] else {
            throw ActivityPubError.missingSignatureHeader
        }

        let algorithmRegex = #/algorithm="(?<algorithm>[^"]*)"/#
        
        let algorithmMatch = signatureHeaderValue.firstMatch(of: algorithmRegex)
        guard let algorithmValue = algorithmMatch?.algorithm else {
            throw ActivityPubError.algorithmNotSpecified
        }
        
        guard algorithmValue == SupportedAlgorithm.rsaSha256.rawValue else {
            throw ActivityPubError.algorithmNotSupported(String(algorithmValue))
        }
    }
        
    public func delete(on context: QueueContext, activity: ActivityDto) throws {
    }
    
    public func follow(on context: QueueContext, activity: ActivityDto) async throws {
        let actorIds = activity.actor.actorIds()
        for actorId in actorIds {
            let domainIsBlockedByInstance = try await self.isDomainBlockedByInstance(on: context, actorId: actorId)
            guard domainIsBlockedByInstance == false else {
                context.logger.warning("Actor: '\(actorId)' is blocked by instance domain blocks.")
                continue
            }
            
            let objects = activity.object.objects()
            for object in objects {
                let domainIsBlockedByUser = try await self.isDomainBlockedByUser(on: context, actorId: object.id)
                guard domainIsBlockedByUser == false else {
                    context.logger.warning("Actor: '\(actorId)' is blocked by user (\(object.id)) domain blocks.")
                    continue
                }
                
                try await self.follow(sourceProfileUrl: actorId, activityPubObject: object, on: context)
            }
        }
    }
    
    public func accept(on context: QueueContext, activity: ActivityDto) throws {
    }
    
    func undo(on context: QueueContext, activity: ActivityDto) async throws {
        let objects = activity.object.objects()
        for object in objects {
            switch object.type {
            case .follow:
                for sourceActorId in activity.actor.actorIds() {
                    try await self.unfollow(sourceActorId: sourceActorId, activityPubObject: object, on: context)
                }
            default:
                context.logger.warning("Undo of '\(object.type)' action is not supported")
            }
        }
    }
        
    private func unfollow(sourceActorId: String, activityPubObject: BaseObjectDto, on context: QueueContext) async throws {
        guard let objects = activityPubObject.object?.objects() else {
            return
        }
        
        for object in objects {
            try await self.unfollow(sourceProfileUrl: sourceActorId, activityPubObject: object, on: context)
        }
    }
    
    private func unfollow(sourceProfileUrl: String, activityPubObject: BaseObjectDto, on context: QueueContext) async throws {
        guard activityPubObject.type == .profile  else {
            throw ActivityPubError.followTypeNotSupported(activityPubObject.type)
        }
        
        context.logger.info("Unfollowing account: '\(activityPubObject.id)' by account '\(sourceProfileUrl)' (from remote server).")

        let followsService = context.application.services.followsService
        let usersService = context.application.services.usersService
        
        let sourceUser = try await usersService.get(on: context.application.db, activityPubProfile: sourceProfileUrl)
        guard let sourceUser else {
            context.logger.warning("Cannot find user '\(sourceProfileUrl)' in local database.")
            return
        }
        
        let targetUser = try await usersService.get(on: context.application.db, activityPubProfile: activityPubObject.id)
        guard let targetUser else {
            context.logger.warning("Cannot find user '\(activityPubObject.id)' in local database.")
            return
        }
        
        _ = try await followsService.unfollow(on: context.application.db, sourceId: sourceUser.requireID(), targetId: targetUser.requireID())
        try await usersService.updateFollowCount(on: context.application.db, for: sourceUser.requireID())
        try await usersService.updateFollowCount(on: context.application.db, for: targetUser.requireID())
    }
    
    private func follow(sourceProfileUrl: String, activityPubObject: BaseObjectDto, on context: QueueContext) async throws {
        guard activityPubObject.type == .profile  else {
            throw ActivityPubError.followTypeNotSupported(activityPubObject.type)
        }
        
        context.logger.info("Following account: '\(activityPubObject.id)' by account '\(sourceProfileUrl)' (from remote server).")

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
                
        let targetUser = try await usersService.get(on: context.application.db, activityPubProfile: activityPubObject.id)
        guard let targetUser else {
            context.logger.warning("Cannot find local user '\(activityPubObject.id)'.")
            return
        }
        
        _ = try await followsService.follow(on: context.application.db, sourceId: remoteUser.requireID(), targetId: targetUser.requireID(), approved: true)
        try await usersService.updateFollowCount(on: context.application.db, for: remoteUser.requireID())
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
        
        let requestHeaders = activityPubRequest.headers + ["(request-target)": "\(activityPubRequest.httpMethod) \(activityPubRequest.httpPath.path())"]
        
        var headersArray: [String] = []
        for headerName in headerNames {
            guard let signatureHeader = requestHeaders.keys.first(where: { $0.lowercased() == headerName.lowercased() }) else {
                throw ActivityPubError.missingSignedHeader(String(headerName))
            }
            
            if signatureHeader.lowercased() == "digest" {
                headersArray.append("\(headerName): SHA-256=\(activityPubRequest.bodyHash ?? "")")
            } else {
                headersArray.append("\(headerName): \(requestHeaders[signatureHeader] ?? "")")
            }
        }
                
        let headersString = headersArray.joined(separator: "\n")
        guard let data = headersString.data(using: .ascii) else {
            throw ActivityPubError.signatureDataNotCreated
        }
        
        return data
    }
    
    private func getSignatureActor(activityPubRequest: ActivityPubRequestDto) throws -> String {
        let actorIds = activityPubRequest.activity.actor.actorIds()        
        guard let firstActor = actorIds.first else {
            throw ActivityPubError.singleActorIsSupportedInSigning
        }
        
        return firstActor
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
    
    public func isDomainBlockedByInstance(on context: QueueContext, actorId: String) async throws -> Bool {
        let instanceBlockedDomainsService = context.application.services.instanceBlockedDomainsService
        
        guard let url = URL(string: actorId) else {
            return false
        }

        return try await instanceBlockedDomainsService.exists(on: context.application.db, url: url)
    }
    
    public func isDomainBlockedByUser(on context: QueueContext, actorId: String) async throws -> Bool {
        let userBlockedDomainsService = context.application.services.userBlockedDomainsService
        
        guard let url = URL(string: actorId) else {
            return false
        }

        return try await userBlockedDomainsService.exists(on: context.application.db, url: url)
    }
}
