//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Testing
import Foundation

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

let statusCase03 =
"""
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://pixelfed.social/p/mczachurski/624586708985817828/activity",
  "type": "Announce",
  "actor": "https://pixelfed.social/users/mczachurski",
  "to": [
    "https://www.w3.org/ns/activitystreams#Public"
  ],
  "cc": [
    "https://pixelfed.social/users/mczachurski",
    "https://pixelfed.social/users/mczachurski/followers"
  ],
  "published": "2023-10-30T12:44:35+0000",
  "object": "https://mastodonapp.uk/@damianward/111322877716364793"
}
"""

@Suite("ActivityDto serialization")
struct ActivityDtoSerialization {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    
    init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
    }
    
    @Test("Activity should serialize with simple single strings")
    func activityShouldSerializeWithSimpleSingleStrings() throws {
        // Arrange.
        let activityDto = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                      type: .follow,
                                      id: "https://example.com/actor-a#1234",
                                      actor: .single(ActorDto(id: "https://example.com/actor-a")),
                                      to: nil,
                                      object: .single(ObjectDto(id: "https://example.com/actor-b")),
                                      summary: nil,
                                      signature: nil,
                                      published: nil)
        
        // Act.
        let jsonData = try self.encoder.encode(activityDto)
        
        // Assert.
        let expectedJSON = """
{"@context":"https:\\/\\/www.w3.org\\/ns\\/activitystreams","actor":"https:\\/\\/example.com\\/actor-a","id":"https:\\/\\/example.com\\/actor-a#1234","object":"https:\\/\\/example.com\\/actor-b","type":"Follow"}
"""
        #expect(expectedJSON == String(data: jsonData, encoding: .utf8)!)
    }
    
    @Test("Activity should serialize with single objects")
    func activityShouldSerializeWithSingleObjects() throws {
        // Arrange.
        let activityDto = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                      type: .follow,
                                      id: "https://example.com/actor-a#1234",
                                      actor: .single(ActorDto(id: "https://example.com/actor-a")),
                                      to: nil,
                                      object: .single(ObjectDto(id: "https://example.com/actor-b")),
                                      summary: nil,
                                      signature: nil,
                                      published: nil)
        
        // Act.
        let jsonData = try self.encoder.encode(activityDto)
        
        // Assert.
        let expectedJSON = """
{"@context":"https:\\/\\/www.w3.org\\/ns\\/activitystreams","actor":"https:\\/\\/example.com\\/actor-a","id":"https:\\/\\/example.com\\/actor-a#1234","object":"https:\\/\\/example.com\\/actor-b","type":"Follow"}
"""
        #expect(expectedJSON == String(data: jsonData, encoding: .utf8)!)
    }
    
    @Test("Activity should serialize with attachments")
    func activityShouldSerializeWithAttachments() throws {
        // Arrange.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: statusCase01.data(using: .utf8)!)
        
        // Act.
        let jsonData = try self.encoder.encode(activityDto)
        
        // Assert.
        let activityDtoDeserialized = try self.decoder.decode(ActivityDto.self, from: jsonData)
        #expect(activityDtoDeserialized.object.objects().count == 1, "Object not serialized corretctly.")
        #expect((activityDtoDeserialized.object.objects().first?.object as? NoteDto)?.attachment?.count == 1, "Attachments not serialized corretctly.")
    }
    
    @Test("Activity should serialize for annoucment")
    func activityShouldSerializeForAnnoucment() throws {
        // Arrange.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: statusCase03.data(using: .utf8)!)
        
        // Act.
        let jsonData = try self.encoder.encode(activityDto)
        
        // Assert.
        let activityDtoDeserialized = try self.decoder.decode(ActivityDto.self, from: jsonData)
        #expect(activityDtoDeserialized.id == "https://pixelfed.social/p/mczachurski/624586708985817828/activity", "Create announe id should deserialize correctly")
        #expect(activityDtoDeserialized.type == .announce, "Create announe type should deserialize correctly")
        #expect(activityDtoDeserialized.actor.actorIds().first == "https://pixelfed.social/users/mczachurski", "Create announe actor should deserialize correctly")
        #expect(activityDtoDeserialized.object.objects().first?.id == "https://mastodonapp.uk/@damianward/111322877716364793", "Create announe object should deserialize correctly")
    }
}
