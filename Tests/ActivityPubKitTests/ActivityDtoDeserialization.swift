//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import XCTest
@testable import ActivityPubKit

final class ActivityDtoDeserialization: XCTestCase {

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
    "id": "https://mastodon.social/users/acrididae",
    "type": "Note",
    "name": "Some note"
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
    "id": "http://sallyA.example.org",
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
    
    func testJsonWithPersonStringShouldDeserialize() throws {

        // Act.
        let activityDto = try JSONDecoder().decode(ActivityDto.self, from: personCase01.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(
            activityDto.actor,
            .single(.object(BaseActorDto(id: "http://sally.example.org", type: .person))),
            "Single person name should deserialize correctly"
        )
    }
    
    func testJsonWithPersonStringArraysShouldDeserialize() throws {

        // Act.
        let activityDto = try JSONDecoder().decode(ActivityDto.self, from: personCase02.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(activityDto.actor, .multiple([
            .object(BaseActorDto(id: "http://sallyA.example.org", type: .person)),
            .object(BaseActorDto(id: "http://sallyB.example.org", type: .person))
        ]), "Multiple person name should deserialize correctly")
    }
    
    func testJsonWithPersonObjectShouldDeserialize() throws {

        // Act.
        let activityDto = try JSONDecoder().decode(ActivityDto.self, from: personCase03.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(
            activityDto.actor,
            .single(.object(BaseActorDto(id: "http://sally.example.org", type: .person))),
            "Single person name should deserialize correctly"
        )
    }
    
    func testJsonWithPersonObjectArraysShouldDeserialize() throws {

        // Act.
        let activityDto = try JSONDecoder().decode(ActivityDto.self, from: personCase04.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(activityDto.actor, .multiple([
            .object(BaseActorDto(id: "http://sallyA.example.org", type: .person)),
            .object(BaseActorDto(id: "http://sallyB.example.org", type: .person))
        ]), "Multiple person name should deserialize correctly")
    }
    
    func testJsonWithPersonMixedArraysShouldDeserialize() throws {

        // Act.
        let activityDto = try JSONDecoder().decode(ActivityDto.self, from: personCase04.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(activityDto.actor, .multiple([
            .object(BaseActorDto(id: "http://sallyA.example.org", type: .person)),
            .object(BaseActorDto(id: "http://sallyB.example.org", type: .person))
        ]), "Multiple person name should deserialize correctly")
    }
    
    func testJsonWithCreateStatusShouldDeserialize() throws {        
        // Act.
        let activityDto = try JSONDecoder().decode(ActivityDto.self, from: statusCase01.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(
            activityDto.id,
            "https://mastodon.social/users/mczachurski/statuses/111000972200397678/activity",
            "Create status id should deserialize correctly"
        )
    }
}

