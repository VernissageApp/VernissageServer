//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Queues
import ActivityPubKit

extension Application.Services {
    struct ActivityPubSignatureServiceKey: StorageKey {
        typealias Value = ActivityPubSignatureServiceType
    }

    var activityPubSignatureService: ActivityPubSignatureServiceType {
        get {
            self.application.storage[ActivityPubSignatureServiceKey.self] ?? ActivityPubSignatureService()
        }
        nonmutating set {
            self.application.storage[ActivityPubSignatureServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ActivityPubSignatureServiceType {
    func validateSignature(on context: QueueContext, activityPubRequest: ActivityPubRequestDto) async throws
    func validateLocalSignature(on context: QueueContext, activityPubRequest: ActivityPubRequestDto) async throws
    func validateAlgorith(on context: QueueContext, activityPubRequest: ActivityPubRequestDto) throws
}

/// A service for managing signatures in the ActivityPub protocol.
final class ActivityPubSignatureService: ActivityPubSignatureServiceType {
    private enum SupportedAlgorithm: String {
        case rsaSha256 = "rsa-sha256"
    }
    
    /// Validate signature.
    public func validateSignature(on context: QueueContext, activityPubRequest: ActivityPubRequestDto) async throws {
        let searchService = context.application.services.searchService
        let cryptoService = context.application.services.cryptoService
        let activityPubService = context.application.services.activityPubService
        
        // Get actor profile URL from activity.
        let actorId = try self.getSignatureActor(activityPubRequest: activityPubRequest)
        
        // Check if the actor's domain is blocked by the instance.
        if try await activityPubService.isDomainBlockedByInstance(on: context.application, actorId: actorId) {
            throw ActivityPubError.domainIsBlockedByInstance(actorId)
        }
        
        // Check if request is not old one.
        try self.verifyTimeWindow(activityPubRequest: activityPubRequest)
        
        // Get headers stored as Data.
        let generatedSignatureData = try self.generateSignatureData(activityPubRequest: activityPubRequest)
        
        // Get signature from header (decoded base64 as Data).
        let signatureData = try self.getSignatureData(activityPubRequest: activityPubRequest)
                
        // Download profile from remote server.
        guard let user = try await searchService.downloadRemoteUser(activityPubProfile: actorId, on: context) else {
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
    
    /// Validate local signature (user is not downloaded from remote).
    public func validateLocalSignature(on context: QueueContext, activityPubRequest: ActivityPubRequestDto) async throws {
        let usersService = context.application.services.usersService
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
        guard let user = try await usersService.get(on: context.application.db, activityPubProfile: actorId) else {
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
        
        // RFC 2616 compliant date.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")

        guard let date = dateFormatter.date(from: dateHeaderValue) else {
            throw ActivityPubError.incorrectDateFormat(dateHeaderValue)
        }
        
        if date < Date.now.addingTimeInterval(-300) {
            throw ActivityPubError.badTimeWindow(dateHeaderValue)
        }
    }
}
