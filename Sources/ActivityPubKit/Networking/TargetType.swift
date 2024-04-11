//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Crypto
import _CryptoExtras

public enum NetworkingError: String, Swift.Error {
    case cannotCreateUrlRequest
}

public enum Method: String {
    case delete = "DELETE", get = "GET", head = "HEAD", patch = "PATCH", post = "POST", put = "PUT"
}

public enum Header: String {
    case contentType = "content-type"
    case accept = "accept"
    case host = "host"
    case userAgent = "user-agent"
    case date = "date"
    case digest = "digest"
    case signature = "signature"
}

public protocol TargetType {
    var method: Method { get }
    var headers: [Header: String]? { get }
    var queryItems: [(String, String)]? { get }
    var httpBody: Data? { get }
}

extension [Header: String] {    
    var contentTypeApplicationJson: [Header: String] {
        var selfCopy = self
        selfCopy[.contentType] = "application/json"
        return selfCopy
    }
    
    var contentTypeApplicationLdJson: [Header: String] {
        var selfCopy = self
        selfCopy[.contentType] = "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""
        return selfCopy
    }
    
    var acceptApplicationJson: [Header: String] {
        var selfCopy = self
        selfCopy[.accept] = "application/json"
        return selfCopy
    }
    
    func host(_ host: String) -> [Header: String] {
        var selfCopy = self
        selfCopy[.host] = host
        return selfCopy
    }
    
    func userAgent(_ userAgent: String) -> [Header: String] {
        var selfCopy = self
        selfCopy[.userAgent] = userAgent
        return selfCopy
    }
    
    var date: [Header: String] {
        // RFC 2616 compliant date.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        let dateString = dateFormatter.string(from: Date.now)
        
        var selfCopy = self
        selfCopy[.date] = dateString
        return selfCopy
    }
    
    func digest(_ body: Data?) -> [Header: String] {
        guard let body else {
            return self
        }

        // Generata SHA256 from body data.
        let bodySHA256 = SHA256.hash(data: body)
        
        // Cahnge SHA256 data into base64 string.
        let bodyBase64SHA256 = Data(bodySHA256).base64EncodedString()

        var selfCopy = self
        selfCopy[.digest] = "SHA-256=\(bodyBase64SHA256)"
        return selfCopy
    }
    
    func signature(actorId: String, privateKeyPem: String, body: Data?, httpMethod: Method, httpPath: String, userAgent: String, host: String) -> [Header: String] {
        // Add all headers required for generating signature into the dictionary.
        var selfCopy = self
            .acceptApplicationJson
            .host(host)
            .date
            .digest(body)
            .contentTypeApplicationLdJson
            .userAgent(userAgent)

        // Generate srting used for generating signature.
        let signedHeaders = self.getSignedHeaders(headers: selfCopy, body: body, httpMethod: httpMethod, httpPath: httpPath)
        
        // Change string into ASCII data bytes.
        let digest = signedHeaders.data(using: .ascii)!

        // Sign data headers with private actor key.
        let privateKey = try? _RSA.Signing.PrivateKey(pemRepresentation: privateKeyPem)
        let signature = try? privateKey?.signature(for: digest, padding: .insecurePKCS1v1_5)
                
        // Change data signatures into base64 string.
        let singnatureBase64 = signature?.rawRepresentation.base64EncodedString() ?? ""
                
        if body != nil {
            selfCopy[.signature] =
"""
keyId="\(actorId)#main-key",headers="(request-target) host date digest content-type user-agent",algorithm="rsa-sha256",signature="\(singnatureBase64)"
"""
        } else {
            selfCopy[.signature] =
"""
keyId="\(actorId)#main-key",headers="(request-target) host date content-type user-agent",algorithm="rsa-sha256",signature="\(singnatureBase64)"
"""
        }

        return selfCopy
    }
    
    private func getSignedHeaders(headers: [Header: String], body: Data?, httpMethod: Method, httpPath: String) -> String {
        if body != nil {
            return
"""
(request-target): \(httpMethod.rawValue.lowercased()) \(httpPath.lowercased())
host: \(headers[.host] ?? "")
date: \(headers[.date] ?? "")
digest: \(headers[.digest] ?? "")
content-type: \(headers[.contentType] ?? "")
user-agent: \(headers[.userAgent] ?? "")
"""
        } else {
            return
"""
(request-target): \(httpMethod.rawValue.lowercased()) \(httpPath.lowercased())
host: \(headers[.host] ?? "")
date: \(headers[.date] ?? "")
content-type: \(headers[.contentType] ?? "")
user-agent: \(headers[.userAgent] ?? "")
"""
        }
    }
}
