//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import XCTest
@testable import ActivityPubKit

final class ActivityDtoDeserialization: XCTestCase {
    
    static let decoder = JSONDecoder()
    static let encoder = JSONEncoder()
    
    override class func setUp() {
        decoder.dateDecodingStrategy = .customISO8601
        encoder.dateEncodingStrategy = .customISO8601
        encoder.outputFormatting = .sortedKeys
    }
    
    private let personCase01 =
"""
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "type": "Delete",
  "actor": "http://sally.example.org",
  "id": "http://ricky.example.org",
  "to": ["obj1", "obj2"],
  "object": "https://mastodon.social/users/acrididae"
}
"""
    
    private let personCase02 =
"""
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "type": "Delete",
  "actor": ["http://sallyA.example.org", "http://sallyB.example.org"],
  "id": "http://ricky.example.org",
  "to": [
    "obj1",
    {
      "id": "https://sallyadams.example.com",
      "name": "Sally Adams",
      "type": "Person"
    }
  ],
  "object": {
    "id": "https://mastodon.social/users/acrididae/354234234",
    "type": "Note",
    "name": "Some note",
    "url": "https://mastodon.social/users/acrididae/354234234",
    "attributedTo": "https://mastodon.social/users/acrididae"
  }
}
"""
    
    private let personCase03 =
"""
{
  "@context": ["https://www.w3.org/ns/activitystreams"],
  "type": "Delete",
  "actor": {
    "id": "http://sally.example.org",
    "type": "Person",
    "name": "Sally Doe"
  },
  "id": "http://ricky.example.org",
  "to": ["obj1", "obj2"],
  "object": "https://mastodon.social/users/acrididae"
}
"""
    
    private let personCase04 =
"""
{
  "@context": ["https://www.w3.org/ns/activitystreams"],
  "type": "Delete",
  "actor": [{
    "id": "http://sallyA.example.org",
    "type": "Person",
    "name": "SallyA Doe"
  },{
    "id": "http://sallyB.example.org",
    "type": "Person",
    "name": "SallyB Doe"
  }],
  "id": "http://ricky.example.org",
  "to": ["obj1", "obj2"],
  "object": "https://mastodon.social/users/acrididae"
}
"""
    
    private let personCase05 =
"""
{
  "@context": ["https://www.w3.org/ns/activitystreams"],
  "type": "Delete",
  "actor": [
    "http://sallyA.example.org",
    {
      "id": "http://sallyB.example.org",
      "type": "Person",
      "name": "SallyB Doe"
    }
  ],
  "id": "http://ricky.example.org",
  "to": ["obj1", "obj2"],
  "object": "https://mastodon.social/users/johndoe",
  "signature": {
    "type": "RsaSignature2017",
    "creator": "https://mastodon.social/users/johndoe#main-key",
    "created": "2023-06-04T16:09:43Z",
    "signatureValue": "bp4dCvXAtiv8jypbJtqtW468gcYOQXK6sM/98SLrkXPptUx4SPticOJAoUgjLrL3OVa=="
  }
}
"""

    private let personCase06 =
"""
{
    "@context": [
        "https://w3id.org/security/v1",
        "https://www.w3.org/ns/activitystreams"
    ],
    "attachment": [
        {
            "name": "MASTODON",
            "type": "PropertyValue",
            "value": "https://mastodon.social/@johndoe"
        },
        {
            "name": "GITHUB",
            "type": "PropertyValue",
            "value": "https://github.com/johndoe"
        }
    ],
    "endpoints": {
        "sharedInbox": "https://example.com/shared/inbox"
    },
    "followers": "https://example.com/actors/johndoe/followers",
    "following": "https://example.com/actors/johndoe/following",
    "icon": {
        "mediaType": "image/jpeg",
        "type": "Image",
        "url": "https://s3.eu-central-1.amazonaws.com/instance/039ebf33d1664d5d849574d0e7191354.jpg"
    },
    "id": "https://example.com/actors/johndoe",
    "image": {
        "mediaType": "image/jpeg",
        "type": "Image",
        "url": "https://s3.eu-central-1.amazonaws.com/instance/2ef4a0f69d0e410ba002df2212e2b63c.jpg"
    },
    "inbox": "https://example.com/actors/johndoe/inbox",
    "manuallyApprovesFollowers": false,
    "name": "John Doe :verified:",
    "outbox": "https://example.com/actors/johndoe/outbox",
    "preferredUsername": "johndoe",
    "publicKey": {
        "id": "https://example.com/actors/johndoe#main-key",
        "owner": "https://example.com/actors/johndoe",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
    },
    "summary": "#iOS/#dotNET developer, #Apple  fanboy, 📷 aspiring photographer",
    "tag": [
        {
            "name": ":verified:",
            "type": "Emoji"
        }
    ],
    "type": "Person",
    "url": "https://example.com/@johndoe"
}
"""
    
    private let personCase07 =
"""
{
    "@context": [
        "https://w3id.org/security/v1",
        "https://www.w3.org/ns/activitystreams"
    ],
    "attachment": [
        {
            "name": "MASTODON",
            "type": "PropertyValue",
            "value": "https://mastodon.social/@johndoe"
        },
        {
            "name": "GITHUB",
            "type": "PropertyValue",
            "value": "https://github.com/johndoe"
        }
    ],
    "endpoints": {
        "sharedInbox": "https://example.com/shared/inbox"
    },
    "followers": "https://example.com/actors/johndoe/followers",
    "following": "https://example.com/actors/johndoe/following",
    "icon": {
        "mediaType": "image/jpeg",
        "type": "Image",
        "url": "https://s3.eu-central-1.amazonaws.com/instance/039ebf33d1664d5d849574d0e7191354.jpg"
    },
    "id": "https://example.com/actors/johndoe",
    "image": {
        "mediaType": "image/jpeg",
        "type": "Image",
        "url": "https://s3.eu-central-1.amazonaws.com/instance/2ef4a0f69d0e410ba002df2212e2b63c.jpg"
    },
    "inbox": "https://example.com/actors/johndoe/inbox",
    "manuallyApprovesFollowers": false,
    "name": "John Doe",
    "outbox": "https://example.com/actors/johndoe/outbox",
    "preferredUsername": "johndoe",
    "publicKey": {
        "id": "https://example.com/actors/johndoe#main-key",
        "owner": "https://example.com/actors/johndoe",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
    },
    "summary": "Test summary",
    "tag": [
        {
            "href": "https://example.com/hashtag/Apple",
            "name": "Apple",
            "type": "Emoji"
        }
    ],
    "type": "Person",
    "url": "https://example.com/@johndoe"
}
"""
    
    private let statusCase01 =
"""
{
   "@context":[
      "https://www.w3.org/ns/activitystreams",
      {
         "ostatus":"http://ostatus.org#",
         "atomUri":"ostatus:atomUri",
         "inReplyToAtomUri":"ostatus:inReplyToAtomUri",
         "conversation":"ostatus:conversation",
         "sensitive":"as:sensitive",
         "toot":"http://joinmastodon.org/ns#",
         "votersCount":"toot:votersCount",
         "blurhash":"toot:blurhash",
         "focalPoint":{
            "@container":"@list",
            "@id":"toot:focalPoint"
         },
         "Hashtag":"as:Hashtag"
      }
   ],
   "id":"https://mastodon.social/users/mczachurski/statuses/111000972200397678/activity",
   "type":"Create",
   "actor":"https://mastodon.social/users/mczachurski",
   "published":"2023-09-03T11:27:00Z",
   "to":[
      "https://www.w3.org/ns/activitystreams#Public"
   ],
   "cc":[
      "https://mastodon.social/users/mczachurski/followers"
   ],
   "object":{
      "id":"https://mastodon.social/users/mczachurski/statuses/111000972200397678",
      "type":"Note",
      "summary":null,
      "inReplyTo":null,
      "published":"2023-09-03T11:27:00Z",
      "url":"https://mastodon.social/@mczachurski/111000972200397678",
      "attributedTo":"https://mastodon.social/users/mczachurski",
      "to":[
         "https://www.w3.org/ns/activitystreams#Public"
      ],
      "cc":[
         "https://mastodon.social/users/mczachurski/followers"
      ],
      "sensitive":false,
      "atomUri":"https://mastodon.social/users/mczachurski/statuses/111000972200397678",
      "inReplyToAtomUri":null,
      "conversation":"tag:mastodon.social,2023-09-03:objectId=527686956:objectType=Conversation",
      "content":"<p>Holidays almost finished. It&#39;s time to review and edit photos from <a href=\\"https://mastodon.social/tags/Prague\\" class=\\"mention hashtag\\" rel=\\"tag\\">#<span>Prague</span></a>, <a href=\\"https://mastodon.social/tags/Gda%C5%84sk\\" class=\\"mention hashtag\\" rel=\\"tag\\">#<span>Gdańsk</span></a>, <a href=\\"https://mastodon.social/tags/Krak%C3%B3w\\" class=\\"mention hashtag\\" rel=\\"tag\\">#<span>Kraków</span></a>, <a href=\\"https://mastodon.social/tags/London\\" class=\\"mention hashtag\\" rel=\\"tag\\">#<span>London</span></a> and <a href=\\"https://mastodon.social/tags/Wroc%C5%82aw\\" class=\\"mention hashtag\\" rel=\\"tag\\">#<span>Wrocław</span></a>. And plan next trips 😉.</p>",
      "contentMap":{
         "en":"<p>Holidays almost finished. It&#39;s time to review and edit photos from <a href=\\"https://mastodon.social/tags/Prague\\" class=\\"mention hashtag\\" rel=\\"tag\\">#<span>Prague</span></a>, <a href=\\"https://mastodon.social/tags/Gda%C5%84sk\\" class=\\"mention hashtag\\" rel=\\"tag\\">#<span>Gdańsk</span></a>, <a href=\\"https://mastodon.social/tags/Krak%C3%B3w\\" class=\\"mention hashtag\\" rel=\\"tag\\">#<span>Kraków</span></a>, <a href=\\"https://mastodon.social/tags/London\\" class=\\"mention hashtag\\" rel=\\"tag\\">#<span>London</span></a> and <a href=\\"https://mastodon.social/tags/Wroc%C5%82aw\\" class=\\"mention hashtag\\" rel=\\"tag\\">#<span>Wrocław</span></a>. And plan next trips 😉.</p>"
      },
      "attachment":[
         {
            "type":"Document",
            "mediaType":"image/png",
            "url":"https://files.mastodon.social/media_attachments/files/111/000/969/389/195/221/original/f264dc16c1ce2a45.png",
            "name":"Screenshot from Capture One (edit RAW photos software) with a lot of different kind of photos.",
            "blurhash":"U48NqcIA9ZX8t8axofs,0JRjxat7D$t8xuIU",
            "focalPoint":[
               0.0,
               0.0
            ],
            "width":2200,
            "height":1384
         }
      ],
      "tag":[
         {
            "type":"Hashtag",
            "href":"https://mastodon.social/tags/prague",
            "name":"#prague"
         },
         {
            "type":"Hashtag",
            "href":"https://mastodon.social/tags/gdansk",
            "name":"#gdansk"
         },
         {
            "type":"Hashtag",
            "href":"https://mastodon.social/tags/krakow",
            "name":"#krakow"
         },
         {
            "type":"Hashtag",
            "href":"https://mastodon.social/tags/london",
            "name":"#london"
         },
         {
            "type":"Hashtag",
            "href":"https://mastodon.social/tags/wroclaw",
            "name":"#wroclaw"
         }
      ],
      "replies":{
         "id":"https://mastodon.social/users/mczachurski/statuses/111000972200397678/replies",
         "type":"Collection",
         "first":{
            "type":"CollectionPage",
            "next":"https://mastodon.social/users/mczachurski/statuses/111000972200397678/replies?only_other_accounts=true&page=true",
            "partOf":"https://mastodon.social/users/mczachurski/statuses/111000972200397678/replies",
            "items":[
               
            ]
         }
      }
   },
   "signature":{
      "type":"RsaSignature2017",
      "creator":"https://mastodon.social/users/mczachurski#main-key",
      "created":"2023-09-03T11:27:01Z",
      "signatureValue":"nmkOoU4owe5P6DYzLmumxjtgI6Xqy8+ikWirIGR6TKWAYp1rRoJTpqD7Hm6BWdRe7wAKcdorI36tI9kYXeYu729xi/o3CH7KFfnaTa/6rB9xn3AlogieRb4oLO3SDoj6eNVk+TsrANJS063DIZCQY0jpQq2m7CRAESSGwM1NNTRao9m48j6GQLmy467SGxQfHLy7fbqwcaIslKb0FtJDdoV87RqmOOKpThGefkwX9IitHGvmqyIYlAGnvGKsGbswAf7SQydrrimW4glJh8H0YPTFhy7Swb36PWuj2ubfZahciRFYdZc7Kgf+ubk9p1zE7mgXjYUGRBH9v/qOw4RhBg=="
   }
}
"""
   
    private let statusCase02 =
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

    let statusCase04 =
"""
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://mastodon.social/users/mczachurski/statuses/111330332088404363/activity",
  "type": "Announce",
  "actor": "https://mastodon.social/users/mczachurski",
  "published": "2023-10-31T15:27:33Z",
  "to": [
    "https://www.w3.org/ns/activitystreams#Public"
  ],
  "cc": [
    "https://mastodon.social/users/TomaszSusul",
    "https://mastodon.social/users/mczachurski/followers"
  ],
  "object": "https://mastodon.social/users/TomaszSusul/statuses/111305598148116184"
}
"""
    
    let statusCase05 =
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
  "id": "https://pixelfed.social/p/mczachurski/650595293594582993/activity",
  "type": "Create",
  "actor": "https://pixelfed.social/users/mczachurski",
  "published": "2024-01-10T07:13:25+00:00",
  "to": [
    "https://www.w3.org/ns/activitystreams#Public"
  ],
  "cc": [
    "https://pixelfed.social/users/mczachurski/followers",
    "https://gram.social/users/Alice"
  ],
  "object": {
    "id": "https://pixelfed.social/p/mczachurski/650595293594582993",
    "type": "Note",
    "summary": null,
    "content": "Extra colours!",
    "inReplyTo": "https://gram.social/p/Alice/650350850687790456",
    "published": "2024-01-10T07:13:25+00:00",
    "url": "https://pixelfed.social/p/mczachurski/650595293594582993",
    "attributedTo": "https://pixelfed.social/users/mczachurski",
    "to": [
      "https://www.w3.org/ns/activitystreams#Public"
    ],
    "cc": [
      "https://pixelfed.social/users/mczachurski/followers",
      "https://gram.social/users/Alice"
    ],
    "sensitive": false,
    "attachment": [],
    "tag": {
      "type": "Mention",
      "href": "https://gram.social/users/Alice",
      "name": "@Alice@gram.social"
    },
    "commentsEnabled": true,
    "capabilities": {
      "announce": "https://www.w3.org/ns/activitystreams#Public",
      "like": "https://www.w3.org/ns/activitystreams#Public",
      "reply": "https://www.w3.org/ns/activitystreams#Public"
    },
    "location": null
  }
}
"""
    
    func testJsonWithPersonStringShouldDeserialize() throws {

        // Act.
        let activityDto = try Self.decoder.decode(ActivityDto.self, from: personCase01.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(
            activityDto.actor,
            .single(ActorDto(id: "http://sally.example.org", type: nil)),
            "Single person name should deserialize correctly"
        )
    }
    
    func testJsonWithPersonStringArraysShouldDeserialize() throws {

        // Act.
        let activityDto = try Self.decoder.decode(ActivityDto.self, from: personCase02.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(activityDto.actor, .multiple([
            ActorDto(id: "http://sallyA.example.org"),
            ActorDto(id: "http://sallyB.example.org")
        ]), "Multiple person name should deserialize correctly")
    }
    
    func testJsonWithPersonObjectShouldDeserialize() throws {

        // Act.
        let activityDto = try Self.decoder.decode(ActivityDto.self, from: personCase03.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(
            activityDto.actor,
            .single(ActorDto(id: "http://sally.example.org", type: .person)),
            "Single person name should deserialize correctly"
        )
    }
    
    func testJsonWithPersonObjectArraysShouldDeserialize() throws {

        // Act.
        let activityDto = try Self.decoder.decode(ActivityDto.self, from: personCase04.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(activityDto.actor, .multiple([
            ActorDto(id: "http://sallyA.example.org", type: .person),
            ActorDto(id: "http://sallyB.example.org", type: .person)
        ]), "Multiple person name should deserialize correctly")
    }
    
    func testJsonWithPersonMixedArraysShouldDeserialize() throws {

        // Act.
        let activityDto = try Self.decoder.decode(ActivityDto.self, from: personCase05.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(activityDto.actor, .multiple([
            ActorDto(id: "http://sallyA.example.org"),
            ActorDto(id: "http://sallyB.example.org", type: .person)
        ]), "Multiple person name should deserialize correctly")
    }
    
    func testJsonWithPersonEmojisShouldDeserialize() throws {

        // Act.
        let personDto = try Self.decoder.decode(PersonDto.self, from: personCase06.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(personDto.tag?.first?.name, ":verified:")
        XCTAssertEqual(personDto.tag?.first?.type, .emoji)
    }
    
    func testJsonWithPersonEmojisClearNameShouldDeserialize() throws {

        // Act.
        let personDto = try Self.decoder.decode(PersonDto.self, from: personCase06.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(personDto.clearName(), "John Doe")
    }

    func testJsonWithPersonFieldsShouldDeserialize() throws {

        // Act.
        let personDto = try Self.decoder.decode(PersonDto.self, from: personCase07.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(personDto.attachment?[0].name, "MASTODON")
        XCTAssertEqual(personDto.attachment?[0].value, "https://mastodon.social/@johndoe")
        XCTAssertEqual(personDto.attachment?[0].type, "PropertyValue")
        
        XCTAssertEqual(personDto.attachment?[1].name, "GITHUB")
        XCTAssertEqual(personDto.attachment?[1].value, "https://github.com/johndoe")
        XCTAssertEqual(personDto.attachment?[1].type, "PropertyValue")
    }
    
    func testJsonWithCreateStatus1ShouldDeserialize() throws {
        // Act.
        let activityDto = try Self.decoder.decode(ActivityDto.self, from: statusCase01.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(
            activityDto.id,
            "https://mastodon.social/users/mczachurski/statuses/111000972200397678/activity",
            "Create status id should deserialize correctly"
        )
    }
    
    func testJsonWithCreateStatus2ShouldDeserialize() throws {
        // Act.
        let activityDto = try Self.decoder.decode(ActivityDto.self, from: statusCase02.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(
            activityDto.id,
            "https://pixelfed.social/p/mczachurski/624592411232880406/activity",
            "Create status id should deserialize correctly"
        )
    }
    
    func testJsonWithCreateAnnounceShouldDeserialize() throws {
        // Act.
        let activityDto = try Self.decoder.decode(ActivityDto.self, from: statusCase03.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(activityDto.id, "https://pixelfed.social/p/mczachurski/624586708985817828/activity", "Create announe id should deserialize correctly")
        XCTAssertEqual(activityDto.type, .announce, "Create announe type should deserialize correctly")
        XCTAssertEqual(activityDto.actor.actorIds().first, "https://pixelfed.social/users/mczachurski", "Create announe actor should deserialize correctly")
        XCTAssertEqual(activityDto.object.objects().first?.id, "https://mastodonapp.uk/@damianward/111322877716364793", "Create announe object should deserialize correctly")
    }
    
    func testJsonWithCreateAnnounceAndPublishedShouldDeserialize() throws {
        // Act.
        let activityDto = try Self.decoder.decode(ActivityDto.self, from: statusCase04.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(activityDto.id, "https://mastodon.social/users/mczachurski/statuses/111330332088404363/activity", "Create announe id should deserialize correctly")
        XCTAssertEqual(activityDto.type, .announce, "Create announe type should deserialize correctly")
        XCTAssertEqual(activityDto.actor.actorIds().first, "https://mastodon.social/users/mczachurski", "Create announe actor should deserialize correctly")
        XCTAssertEqual(activityDto.object.objects().first?.id, "https://mastodon.social/users/TomaszSusul/statuses/111305598148116184", "Create announe object should deserialize correctly")
    }
    
    func testJsonWithCreateStatus5ShouldDeserialize() throws {
        // Act.
        let activityDto = try Self.decoder.decode(ActivityDto.self, from: statusCase05.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(
            activityDto.id,
            "https://pixelfed.social/p/mczachurski/650595293594582993/activity",
            "Create status id should deserialize correctly"
        )
        
        let noteDto = activityDto.object.objects().first?.object as? NoteDto
        XCTAssertNotNil(noteDto, "Note should be deserialized")
    }
}

