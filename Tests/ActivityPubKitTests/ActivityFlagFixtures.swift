//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum ActivityFlagFixtures {
    static let flagJson =
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

    static let expectedFlagActivityId = "https://mastodon.example/ccb4f39a-506a-490e-9a8c-71831c7713a4"
    static let expectedFlagActorIds = ["https://mastodon.example/actor"]
    static let expectedFlagObjectIds = [
        "https://example.com/users/1",
        "https://example.com/posts/380590",
        "https://example.com/posts/380591"
    ]
    static let expectedFlagToActorIds = ["https://example.com/users/1"]
    static let expectedFlagContent = "Please review this account and its posts."

    static let reportedActorId = "https://remote.example/users/1"
    static let reportedObjectIds = [
        "https://remote.example/posts/1",
        "https://remote.example/posts/2"
    ]
    static let reportedContent = "Reported from Vernissage."

    static let expectedReportedActorOnlyJson =
"""
{"@context":"https:\\/\\/www.w3.org\\/ns\\/activitystreams","actor":"https:\\/\\/vernissage.example\\/actor","id":"https:\\/\\/vernissage.example\\/actor#flags\\/1","object":"https:\\/\\/remote.example\\/users\\/1","to":"https:\\/\\/remote.example\\/users\\/1","type":"Flag"}
"""

    static let expectedReportedActorAndObjectsJson =
"""
{"@context":"https:\\/\\/www.w3.org\\/ns\\/activitystreams","actor":"https:\\/\\/vernissage.example\\/actor","content":"Reported from Vernissage.","id":"https:\\/\\/vernissage.example\\/actor#flags\\/2","object":["https:\\/\\/remote.example\\/users\\/1","https:\\/\\/remote.example\\/posts\\/1","https:\\/\\/remote.example\\/posts\\/2"],"to":"https:\\/\\/remote.example\\/users\\/1","type":"Flag"}
"""
}
