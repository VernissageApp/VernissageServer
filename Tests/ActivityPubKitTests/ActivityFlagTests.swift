//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Testing
import Foundation

@Suite("Activity Flag")
struct ActivityFlagTests {
    let decoder = JSONDecoder()
    
    @Test
    func `Flag activity should deserialize with content and multiple reported objects`() throws {
        // Arrange.
        let flagJson =
"""
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://mastodon.example/ccb4f39a-506a-490e-9a8c-71831c7713a4",
  "type": "Flag",
  "actor": "https://mastodon.example/actor",
  "content": "Please review this account and its posts.",
  "object": [
    "https://example.com/users/1",
    "https://example.com/posts/380590",
    "https://example.com/posts/380591"
  ],
  "to": "https://example.com/users/1"
}
"""
        
        // Act.
        let activityDto = try decoder.decode(ActivityDto.self, from: flagJson.data(using: .utf8)!)
        
        // Assert.
        #expect(activityDto.id == "https://mastodon.example/ccb4f39a-506a-490e-9a8c-71831c7713a4")
        #expect(activityDto.type == .flag)
        #expect(activityDto.actor.actorIds() == ["https://mastodon.example/actor"])
        #expect(activityDto.object.objects().map(\.id) == [
            "https://example.com/users/1",
            "https://example.com/posts/380590",
            "https://example.com/posts/380591"
        ])
        #expect(activityDto.to?.actorIds() == ["https://example.com/users/1"])
        #expect(activityDto.content == "Please review this account and its posts.")
    }
    
    @Test
    func `Flag target should create activity for reported actor`() throws {
        // Arrange.
        let target = ActivityPub.Flag.create(
            "1",
            "https://vernissage.example/actor",
            "https://remote.example/users/1",
            [],
            nil,
            "private-key",
            "/inbox",
            "Vernissage",
            "remote.example"
        )
        
        // Act.
        let jsonData = try #require(target.httpBody)
        
        // Assert.
        let expectedJson = """
{"@context":"https:\\/\\/www.w3.org\\/ns\\/activitystreams","actor":"https:\\/\\/vernissage.example\\/actor","id":"https:\\/\\/vernissage.example\\/actor#flags\\/1","object":"https:\\/\\/remote.example\\/users\\/1","to":"https:\\/\\/remote.example\\/users\\/1","type":"Flag"}
"""
        #expect(expectedJson == String(data: jsonData, encoding: .utf8)!)
    }
    
    @Test
    func `Flag target should create activity for reported actor and objects`() throws {
        // Arrange.
        let target = ActivityPub.Flag.create(
            "2",
            "https://vernissage.example/actor",
            "https://remote.example/users/1",
            [
                "https://remote.example/posts/1",
                "https://remote.example/posts/2"
            ],
            "Reported from Vernissage.",
            "private-key",
            "/shared/inbox",
            "Vernissage",
            "remote.example"
        )
        
        // Act.
        let jsonData = try #require(target.httpBody)
        
        // Assert.
        let expectedJson = """
{"@context":"https:\\/\\/www.w3.org\\/ns\\/activitystreams","actor":"https:\\/\\/vernissage.example\\/actor","content":"Reported from Vernissage.","id":"https:\\/\\/vernissage.example\\/actor#flags\\/2","object":["https:\\/\\/remote.example\\/users\\/1","https:\\/\\/remote.example\\/posts\\/1","https:\\/\\/remote.example\\/posts\\/2"],"to":"https:\\/\\/remote.example\\/users\\/1","type":"Flag"}
"""
        #expect(expectedJson == String(data: jsonData, encoding: .utf8)!)
    }
}
