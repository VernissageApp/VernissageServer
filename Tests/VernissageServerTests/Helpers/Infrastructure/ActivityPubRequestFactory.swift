//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
@testable import ActivityPubKit
import Crypto
import _CryptoExtras
import Foundation

enum ActivityPubRequestFactory {
    static func followRequest(sourceUser: User, targetUser: User, followId: Int64) throws -> ActivityPubRequestDto {
        let followTarget = ActivityPub.Users.follow(sourceUser.activityPubProfile,
                                                    targetUser.activityPubProfile,
                                                    sourceUser.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost",
                                                    followId)
        guard let body = followTarget.httpBody else {
            throw ActivityPubError.signatureDataNotCreated
        }

        let activity = try JSONDecoder().decode(ActivityDto.self, from: body)
        let bodyHash = Data(SHA256.hash(data: body)).base64EncodedString()
        let headers = self.headersDictionary(from: followTarget.headers ?? [:])

        return ActivityPubRequestDto(activity: activity,
                                     headers: headers,
                                     bodyHash: bodyHash,
                                     bodyValue: String(data: body, encoding: .utf8) ?? "",
                                     httpMethod: .post,
                                     httpPath: .sharedInbox)
    }

    static func signedMoveRequest(payloadActorId: String,
                                  targetActorId: String,
                                  signatureActorId: String,
                                  signaturePrivateKey: String,
                                  requestPath: String = "/shared/inbox",
                                  requestHost: String = "localhost",
                                  signedAt: Date = .now,
                                  moveId: Int64) throws -> ActivityPubRequestDto {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let body = try encoder.encode(
            ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                        type: .move,
                        id: "\(payloadActorId)#move/\(moveId)",
                        actor: .single(ActorDto(id: payloadActorId)),
                        to: .single(ActorDto(id: "\(payloadActorId)/followers")),
                        object: .single(ObjectDto(id: payloadActorId)),
                        target: .single(ActorDto(id: targetActorId)),
                        summary: nil,
                        signature: nil,
                        published: nil)
        )

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        let date = dateFormatter.string(from: signedAt)

        let bodyHash = Data(SHA256.hash(data: body)).base64EncodedString()
        let digest = "SHA-256=\(bodyHash)"
        let signedHeaders =
"""
(request-target): post \(requestPath)
host: \(requestHost)
date: \(date)
digest: \(digest)
"""

        let signatureDigest = signedHeaders.data(using: .ascii)!
        let privateKey = try _RSA.Signing.PrivateKey(pemRepresentation: signaturePrivateKey)
        let signature = try privateKey.signature(for: signatureDigest, padding: .insecurePKCS1v1_5)
        let signatureBase64 = signature.rawRepresentation.base64EncodedString()

        let headers = [
            "accept": "application/activity+json",
            "host": requestHost,
            "date": date,
            "digest": digest,
            "content-type": "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"",
            "user-agent": Constants.userAgent,
            "signature": "keyId=\"\(signatureActorId)#main-key\",headers=\"(request-target) host date digest\",algorithm=\"rsa-sha256\",signature=\"\(signatureBase64)\""
        ]

        let activity = try JSONDecoder().decode(ActivityDto.self, from: body)
        return ActivityPubRequestDto(activity: activity,
                                     headers: headers,
                                     bodyHash: bodyHash,
                                     bodyValue: String(data: body, encoding: .utf8) ?? "",
                                     httpMethod: .post,
                                     httpPath: .sharedInbox)
    }

    static func requestByReplacingHeaders(request: ActivityPubRequestDto, headers: [String: String]) -> ActivityPubRequestDto {
        ActivityPubRequestDto(activity: request.activity,
                              headers: headers,
                              bodyHash: request.bodyHash,
                              bodyValue: request.bodyValue,
                              httpMethod: request.httpMethod,
                              httpPath: request.httpPath,
                              receivedAt: request.receivedAt)
    }
    
    static func requestByReplacingReceivedAt(request: ActivityPubRequestDto, receivedAt: Date?) -> ActivityPubRequestDto {
        ActivityPubRequestDto(activity: request.activity,
                              headers: request.headers,
                              bodyHash: request.bodyHash,
                              bodyValue: request.bodyValue,
                              httpMethod: request.httpMethod,
                              httpPath: request.httpPath,
                              receivedAt: receivedAt)
    }

    static func signedDeleteUserRequest(actorId: String,
                                        objectId: String,
                                        signaturePrivateKey: String,
                                        requestPath: String = "/shared/inbox",
                                        requestHost: String = "localhost") throws -> (headers: [String: String], body: Data) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let body = try encoder.encode(
            ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                        type: .delete,
                        id: "\(actorId)#delete",
                        actor: .single(ActorDto(id: actorId)),
                        to: .multiple([ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")]),
                        object: .single(ObjectDto(id: objectId, type: .person)),
                        summary: nil,
                        signature: nil,
                        published: nil)
        )

        let bodyHash = Data(SHA256.hash(data: body)).base64EncodedString()
        let digest = "SHA-256=\(bodyHash)"

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        let date = dateFormatter.string(from: .now)

        let signedHeaders =
"""
(request-target): post \(requestPath)
host: \(requestHost)
date: \(date)
digest: \(digest)
"""

        let signatureDigest = signedHeaders.data(using: .ascii)!
        let privateKey = try _RSA.Signing.PrivateKey(pemRepresentation: signaturePrivateKey)
        let signature = try privateKey.signature(for: signatureDigest, padding: .insecurePKCS1v1_5)
        let signatureBase64 = signature.rawRepresentation.base64EncodedString()

        let headers = [
            "accept": "application/activity+json",
            "host": requestHost,
            "date": date,
            "digest": digest,
            "content-type": "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"",
            "user-agent": Constants.userAgent,
            "signature": "keyId=\"\(actorId)#main-key\",headers=\"(request-target) host date digest\",algorithm=\"rsa-sha256\",signature=\"\(signatureBase64)\""
        ]

        return (headers, body)
    }

    private static func headersDictionary(from headers: [Header: String]) -> [String: String] {
        var dictionary: [String: String] = [:]
        for (header, value) in headers {
            dictionary[header.rawValue] = value
        }

        return dictionary
    }
}
