//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
@testable import ActivityPubKit
import Vapor
import Testing
import Queues

@Suite("UsersServiceTests")
struct UsersServiceTests {
        
    var application: Application!
    
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    
    init() {
        decoder.dateDecodingStrategy = .customISO8601
        encoder.dateEncodingStrategy = .customISO8601
        encoder.outputFormatting = .sortedKeys
    }
    
    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }
    
    @Test
    func `Correct user name should be calculated when id and url exists`() async throws {
        let personJson =
"""
{
    "@context": [
        "https://w3id.org/security/v1",
        "https://www.w3.org/ns/activitystreams"
    ],
    "followers": "https://example.com/actors/johndoe/followers",
    "following": "https://example.com/actors/johndoe/following",
    "inbox": "https://example.com/actors/johndoe/inbox",
    "manuallyApprovesFollowers": false,
    "name": "John Doe :verified:",
    "outbox": "https://example.com/actors/johndoe/outbox",
    "publicKey": {
        "id": "https://example.com/actors/johndoe#main-key",
        "owner": "https://example.com/actors/johndoe",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
    },
    "summary": "#iOS/#dotNET developer, #Apple  fanboy, 📷 aspiring photographer",
    "type": "Person",
    "preferredUsername": "johndoe@mastodon.com",
    "id": "https://example.com/actors/johndoe",
    "url": "https://example.com/@johndoe"
}
"""
        
        let personDto = try self.decoder.decode(PersonDto.self, from: personJson.data(using: .utf8)!)
        
        let userName = try personDto.getRemoteUserName()
        #expect(userName == "johndoe@mastodon.com")
    }
    
    @Test
    func `Correct user name should be calculated preferredUsername already contains hostname`() async throws {
        let personJson =
"""
{
    "@context": [
        "https://w3id.org/security/v1",
        "https://www.w3.org/ns/activitystreams"
    ],
    "followers": "https://example.com/actors/johndoe/followers",
    "following": "https://example.com/actors/johndoe/following",
    "inbox": "https://example.com/actors/johndoe/inbox",
    "manuallyApprovesFollowers": false,
    "name": "John Doe :verified:",
    "outbox": "https://example.com/actors/johndoe/outbox",
    "publicKey": {
        "id": "https://example.com/actors/johndoe#main-key",
        "owner": "https://example.com/actors/johndoe",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
    },
    "summary": "#iOS/#dotNET developer, #Apple  fanboy, 📷 aspiring photographer",
    "type": "Person",
    "preferredUsername": "johndoe",
    "id": "https://example.com/actors/johndoe",
    "url": "https://example.com/@johndoe"
}
"""
        
        let personDto = try self.decoder.decode(PersonDto.self, from: personJson.data(using: .utf8)!)
        
        let userName = try personDto.getRemoteUserName()
        #expect(userName == "johndoe@example.com")
    }
    
    @Test
    func `Correct user name should be calculated when url not exists`() async throws {
        let personJson =
"""
{
    "@context": [
        "https://w3id.org/security/v1",
        "https://www.w3.org/ns/activitystreams"
    ],
    "followers": "https://example.com/actors/johndoe/followers",
    "following": "https://example.com/actors/johndoe/following",
    "inbox": "https://example.com/actors/johndoe/inbox",
    "manuallyApprovesFollowers": false,
    "name": "John Doe :verified:",
    "outbox": "https://example.com/actors/johndoe/outbox",
    "publicKey": {
        "id": "https://example.com/actors/johndoe#main-key",
        "owner": "https://example.com/actors/johndoe",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
    },
    "summary": "#iOS/#dotNET developer, #Apple  fanboy, 📷 aspiring photographer",
    "type": "Person",
    "preferredUsername": "johndoe",
    "id": "https://example.com/actors/johndoe"
}
"""
        let personDto = try self.decoder.decode(PersonDto.self, from: personJson.data(using: .utf8)!)
        
        let userName = try personDto.getRemoteUserName()
        #expect(userName == "johndoe@example.com")
    }
    
    @Test
    func `Correct user name should be calculated when id and url are different`() async throws {
        let personJson =
"""
{
    "@context": [
        "https://w3id.org/security/v1",
        "https://www.w3.org/ns/activitystreams"
    ],
    "followers": "https://example.com/actors/johndoe/followers",
    "following": "https://example.com/actors/johndoe/following",
    "inbox": "https://example.com/actors/johndoe/inbox",
    "manuallyApprovesFollowers": false,
    "name": "John Doe :verified:",
    "outbox": "https://example.com/actors/johndoe/outbox",
    "publicKey": {
        "id": "https://example.com/actors/johndoe#main-key",
        "owner": "https://example.com/actors/johndoe",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
    },
    "summary": "#iOS/#dotNET developer, #Apple  fanboy, 📷 aspiring photographer",
    "type": "Person",
    "preferredUsername": "johndoe",
    "id": "https://example.com/actors/johndoe",
    "url": "https://twitter.com/@johndoe"
}
"""
        let personDto = try self.decoder.decode(PersonDto.self, from: personJson.data(using: .utf8)!)
        
        let userName = try personDto.getRemoteUserName()
        #expect(userName == "johndoe@example.com")
    }
    
    @Test
    func `Correct user name should be calculated when id is not an url and url has been specified`() async throws {
        let personJson =
"""
{
    "@context": [
        "https://w3id.org/security/v1",
        "https://www.w3.org/ns/activitystreams"
    ],
    "followers": "https://example.com/actors/johndoe/followers",
    "following": "https://example.com/actors/johndoe/following",
    "inbox": "https://example.com/actors/johndoe/inbox",
    "manuallyApprovesFollowers": false,
    "name": "John Doe :verified:",
    "outbox": "https://example.com/actors/johndoe/outbox",
    "publicKey": {
        "id": "https://example.com/actors/johndoe#main-key",
        "owner": "https://example.com/actors/johndoe",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
    },
    "summary": "#iOS/#dotNET developer, #Apple  fanboy, 📷 aspiring photographer",
    "type": "Person",
    "preferredUsername": "johndoe",
    "id": "adres/johndoe",
    "url": "https://example.com/@johndoe"
}
"""
        let personDto = try self.decoder.decode(PersonDto.self, from: personJson.data(using: .utf8)!)
        
        let userName = try personDto.getRemoteUserName()
        #expect(userName == "johndoe@example.com")
    }
    
    @Test
    func `Exception should be thrown when id is not a url and url is empty`() async throws {
        let personJson =
"""
{
    "@context": [
        "https://w3id.org/security/v1",
        "https://www.w3.org/ns/activitystreams"
    ],
    "followers": "https://example.com/actors/johndoe/followers",
    "following": "https://example.com/actors/johndoe/following",
    "inbox": "https://example.com/actors/johndoe/inbox",
    "manuallyApprovesFollowers": false,
    "name": "John Doe :verified:",
    "outbox": "https://example.com/actors/johndoe/outbox",
    "publicKey": {
        "id": "https://example.com/actors/johndoe#main-key",
        "owner": "https://example.com/actors/johndoe",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
    },
    "summary": "#iOS/#dotNET developer, #Apple  fanboy, 📷 aspiring photographer",
    "type": "Person",
    "preferredUsername": "johndoe",
    "id": "adres/johndoe",
    "url": ""
}
"""
        let personDto = try self.decoder.decode(PersonDto.self, from: personJson.data(using: .utf8)!)
        
        #expect(throws: PersonError.missingUrl, "Incorrect id and empty url should throw an error") {
            try personDto.getRemoteUserName()
        }
    }
    
    @Test
    func `Exception should be thrown when id is not a url and url not exists`() async throws {
        let personJson =
"""
{
    "@context": [
        "https://w3id.org/security/v1",
        "https://www.w3.org/ns/activitystreams"
    ],
    "followers": "https://example.com/actors/johndoe/followers",
    "following": "https://example.com/actors/johndoe/following",
    "inbox": "https://example.com/actors/johndoe/inbox",
    "manuallyApprovesFollowers": false,
    "name": "John Doe :verified:",
    "outbox": "https://example.com/actors/johndoe/outbox",
    "publicKey": {
        "id": "https://example.com/actors/johndoe#main-key",
        "owner": "https://example.com/actors/johndoe",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
    },
    "summary": "#iOS/#dotNET developer, #Apple  fanboy, 📷 aspiring photographer",
    "type": "Person",
    "preferredUsername": "johndoe",
    "id": "adres/johndoe"
}
"""
        let personDto = try self.decoder.decode(PersonDto.self, from: personJson.data(using: .utf8)!)
        
        #expect(throws: PersonError.missingUrl, "Incorrect id and not existing url should throw an error") {
            try personDto.getRemoteUserName()
        }
    }
}
