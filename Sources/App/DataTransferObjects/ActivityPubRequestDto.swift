//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

final class ActivityPubRequestDto {
    let activity: ActivityDto
    let headers: [String: String]
    let bodyHash: String?
    let httpMethod: ActivityPubRequestMethod
    let httpPath: ActivityPubRequestPath
    
    init(activity: ActivityDto, headers: [String: String], bodyHash: String?, httpMethod: ActivityPubRequestMethod, httpPath: ActivityPubRequestPath) {
        self.activity = activity
        self.headers = headers
        self.bodyHash = bodyHash
        self.httpMethod = httpMethod
        self.httpPath = httpPath
    }
    
    init(cryptoService: CryptoService,
         privateKey: String,
         activity: ActivityDto,
         basePath: String,
         version: String,
         actorId: String,
         httpMethod: ActivityPubRequestMethod = .post,
         httpPath: ActivityPubRequestPath = .sharedInbox) throws {
        self.activity = activity
        self.httpMethod = httpMethod
        self.httpPath = httpPath
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        let dateString = dateFormatter.string(from: Date.now)
        
        let bodyHash = try activity.getSHA256Base64String()
        self.bodyHash = bodyHash
        
        // Prepare data for 'Signature' header.
        let signedHeaders = """
(request-target): \(self.httpMethod) \(self.httpPath.path())
host: \(basePath)
date: \(dateString)
digest: SHA-256=\(bodyHash)
content-type: application/ld+json; profile="https://www.w3.org/ns/activitystreams"
user-agent: (Vernissage/\(version); +https://\(basePath)
"""

        // Prepare signature based on private key.
        let singnatureBase64 = try cryptoService.generateSignatureBase64(privateKeyPem: privateKey, digest: signedHeaders.data(using: .ascii)!)
        
        let headers: [String: String] = [
            "date": dateString,
            "digest": "SHA-256=\(bodyHash)",
            "content-type": "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"",
            "user-agent": "(Vernissage/\(version); +https://\(basePath)",
            "signature":
"""
keyId="\(actorId)#main-key",headers="(request-target) host date digest content-type user-agent",algorithm="rsa-sha256",signature="\(singnatureBase64)"
""",
            "host": basePath
        ]
        
        self.headers = headers
    }
}

extension ActivityPubRequestDto: Content { }
