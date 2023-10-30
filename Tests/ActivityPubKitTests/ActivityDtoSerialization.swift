//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import XCTest
@testable import ActivityPubKit

private let statusCase01 =
"""
{
"@context": [
"https://w3id.org/security/v1",
"https://www.w3.org/ns/activitystreams",
{
  "Hashtag": "as:Hashtag",
  "sensitive": "as:sensitive",
  "schema": "http://schema.org/",
  "pixelfed": "http://pixelfed.org/ns#",
  "commentsEnabled": {
    "@id": "pixelfed:commentsEnabled",
    "@type": "schema:Boolean"
  },
  "capabilities": {
    "@id": "pixelfed:capabilities",
    "@container": "@set"
  },
  "announce": {
    "@id": "pixelfed:canAnnounce",
    "@type": "@id"
  },
  "like": {
    "@id": "pixelfed:canLike",
    "@type": "@id"
  },
  "reply": {
    "@id": "pixelfed:canReply",
    "@type": "@id"
  },
  "toot": "http://joinmastodon.org/ns#",
  "Emoji": "toot:Emoji",
  "blurhash": "toot:blurhash"
}
],
"id": "https://pixelfed.social/p/mczachurski/624592411232880406/activity",
"type": "Create",
"actor": "https://pixelfed.social/users/mczachurski",
"published": "2023-10-30T13:07:15+00:00",
"to": [
"https://www.w3.org/ns/activitystreams#Public"
],
"cc": [
"https://pixelfed.social/users/mczachurski/followers"
],
"object": {
"id": "https://pixelfed.social/p/mczachurski/624592411232880406",
"type": "Note",
"summary": null,
"content": "Shadows <a href=\\"https://pixelfed.social/discover/tags/colorphotography?src=hash\\" title=\\"#colorphotography\\" class=\\"u-url hashtag\\" rel=\\"external nofollow noopener\\">#colorphotography</a> <a href=\\"https://pixelfed.social/discover/tags/streetphotography?src=hash\\" title=\\"#streetphotography\\" class=\\"u-url hashtag\\" rel=\\"external nofollow noopener\\">#streetphotography</a>",
"inReplyTo": null,
"published": "2023-10-30T13:07:15+00:00",
"url": "https://pixelfed.social/p/mczachurski/624592411232880406",
"attributedTo": "https://pixelfed.social/users/mczachurski",
"to": [
  "https://www.w3.org/ns/activitystreams#Public"
],
"cc": [
  "https://pixelfed.social/users/mczachurski/followers"
],
"sensitive": false,
"attachment": [
  {
    "type": "Image",
    "mediaType": "image/jpeg",
    "url": "https://pxscdn.com/public/m/_v2/502420301986951048/f1538e3aa-7b3151/NUalEqHRyJfn/YPp7nvccWGSAPcalvb0PvEuDQzcsQZgyCEjsTrFx.jpg",
    "name": "Stickers on the glass from the stairs, casting long and colourful shadows from the sun.",
    "blurhash": "U9AmM5?GIp9b~UNGoeRk4=E2oeax4;ofxtWB",
    "width": 1620,
    "height": 1080
  }
],
"tag": [
  {
    "type": "Hashtag",
    "href": "https://pixelfed.social/discover/tags/streetphotography",
    "name": "#streetphotography"
  },
  {
    "type": "Hashtag",
    "href": "https://pixelfed.social/discover/tags/colorphotography",
    "name": "#colorphotography"
  }
],
"commentsEnabled": true,
"capabilities": {
  "announce": "https://www.w3.org/ns/activitystreams#Public",
  "like": "https://www.w3.org/ns/activitystreams#Public",
  "reply": "https://www.w3.org/ns/activitystreams#Public"
},
"location": {
  "type": "Place",
  "name": "Wrocław",
  "longitude": "17.033330",
  "latitude": "51.100000",
  "country": "Poland"
}
}
}
"""

final class ActivityDtoSerialization: XCTestCase {
    func testActivityShouldSerializeWithSimpleSingleStrings() throws {
        // Arrange.
        let activityDto = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                      type: .follow,
                                      id: "https://example.com/actor-a#1234",
                                      actor: .single(.string("https://example.com/actor-a")),
                                      to: nil,
                                      object: .single(.string("https://example.com/actor-b")),
                                      summary: nil,
                                      signature: nil)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        // Act.
        let jsonData = try encoder.encode(activityDto)
        
        // Assert.
        let expectedJSON = """
{"@context":"https:\\/\\/www.w3.org\\/ns\\/activitystreams","actor":"https:\\/\\/example.com\\/actor-a","id":"https:\\/\\/example.com\\/actor-a#1234","object":"https:\\/\\/example.com\\/actor-b","type":"Follow"}
"""
        XCTAssertEqual(expectedJSON, String(data: jsonData, encoding: .utf8)!)
    }
    
    func testActivityShouldSerializeWithSingleObjects() throws {
        // Arrange.
        let activityDto = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                      type: .follow,
                                      id: "https://example.com/actor-a#1234",
                                      actor: .single(.object(BaseActorDto(id: "https://example.com/actor-a", type: .person))),
                                      to: nil,
                                      object: .single(.object(BaseObjectDto(id: "https://example.com/actor-b", type: .profile))),
                                      summary: nil,
                                      signature: nil)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        // Act.
        let jsonData = try encoder.encode(activityDto)
        
        // Assert.
        let expectedJSON = """
{"@context":"https:\\/\\/www.w3.org\\/ns\\/activitystreams","actor":{"id":"https:\\/\\/example.com\\/actor-a","name":null,"type":"Person"},"id":"https:\\/\\/example.com\\/actor-a#1234","object":{"actor":null,"attachment":null,"content":null,"contentWarning":null,"id":"https:\\/\\/example.com\\/actor-b","name":null,"object":null,"sensitive":null,"to":null,"type":"Profile","url":null},"type":"Follow"}
"""
        XCTAssertEqual(expectedJSON, String(data: jsonData, encoding: .utf8)!)
    }
    
    func testActivityShouldSerializeWithAttachments() throws {
        // Arrange.
        let activityDto = try JSONDecoder().decode(ActivityDto.self, from: statusCase01.data(using: .utf8)!)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        // Act.
        let jsonData = try encoder.encode(activityDto)
        
        // Assert.
        let activityDtoDeserialized = try JSONDecoder().decode(ActivityDto.self, from: jsonData)
        XCTAssertEqual(1, activityDtoDeserialized.object.objects().count, "Object not serialized corretctly.")
        XCTAssertEqual(1, activityDtoDeserialized.object.objects().first?.attachment?.count, "Attachments not serialized corretctly.")
    }
}
