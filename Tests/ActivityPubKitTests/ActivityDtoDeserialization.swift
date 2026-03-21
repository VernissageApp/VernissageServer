//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Testing
import Foundation

@Suite("ActivityDto deserialization")
struct ActivityDtoDeserialization {
    
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    
    init() {
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
            "href": "https://example.com/tags/Apple",
            "name": "Apple",
            "type": "Emoji"
        }
    ],
    "type": "Person",
    "url": "https://example.com/@johndoe"
}
"""
    
    private let personCase08 =
"""
{
    "@context": [
        "https://w3id.org/security/v1",
        "https://www.w3.org/ns/activitystreams"
    ],
    "attachment": [],
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
    "name": "John Doe",
    "outbox": "https://example.com/actors/johndoe/outbox",
    "preferredUsername": "johndoe",
    "publicKey": {
        "id": "https://example.com/actors/johndoe#main-key",
        "owner": "https://example.com/actors/johndoe",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
    },
    "summary": "Test summary",
    "tag": [],
    "type": "Person",
    "url": "https://example.com/@johndoe"
}
"""
    private let personCase09 =
"""
{
   "@context":[
      "https://www.w3.org/ns/activitystreams",
      "https://purl.archive.org/miscellany",
      "https://w3id.org/security/v1",
      {
         "alsoKnownAs":{
            "@id":"as:alsoKnownAs",
            "@type":"@id"
         }
      }
   ],
   "alsoKnownAs":[
      "https://bsky.brid.gy/",
      "https://fed.brid.gy/"
   ],
   "endpoints":{
      "sharedInbox":"https://bsky.brid.gy/ap/sharedInbox"
   },
   "followers":"https://bsky.brid.gy/bsky.brid.gy/followers",
   "following":"https://bsky.brid.gy/bsky.brid.gy/following",
   "icon":[
      {
         "name":"Bridgy Fed for Bluesky",
         "type":"Image",
         "url":"https://fed.brid.gy/static/bridgy_logo_square.jpg"
      },
      {
         "name":"Bridgy Fed for Bluesky",
         "type":"Image",
         "url":"https://fed.brid.gy/static/bridgy_logo2.jpg"
      }
   ],
   "id":"https://bsky.brid.gy/bsky.brid.gy",
   "image":[
      {
         "type":"Image",
         "url":"https://fed.brid.gy/static/bridgy_fed_banner.png"
      },
      {
         "name":"Bridgy Fed for Bluesky",
         "type":"Image",
         "url":"https://fed.brid.gy/static/bridgy_logo_square.jpg"
      }
   ],
   "inbox":"https://bsky.brid.gy/bsky.brid.gy/inbox",
   "manuallyApprovesFollowers":false,
   "name":"Bridgy Fed for Bluesky",
   "outbox":"https://bsky.brid.gy/bsky.brid.gy/outbox",
   "preferredUsername":"bsky.brid.gy",
   "publicKey":{
      "id":"https://bsky.brid.gy/bsky.brid.gy#key",
      "owner":"https://bsky.brid.gy/bsky.brid.gy",
      "publicKeyPem":"-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
   },
   "summary":"<p><a href='https://fed.brid.gy/'>Bridgy Fed</a> bot user for <a href='https://bsky.social/'>Bluesky</a>. To bridge your fediverse account to Bluesky, follow this account. <a href='https://fed.brid.gy/docs'>More info here.</a><p>After you follow this account, it will follow you back. Accept its follow to make sure your fediverse posts get sent to the bridge and make it into Bluesky.<p>To ask a Bluesky user to bridge their account, DM their handle (eg snarfed.bsky.social) to this account.</p>",
   "type":"Service",
   "url":[
      "https://bsky.brid.gy/",
      "https://fed.brid.gy/"
   ]
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
    
    private let personCase10 =
"""
{
    "@context": [
        "https://www.w3.org/ns/activitystreams",
        "https://w3id.org/security/v1"
    ],
    "id": "https://example.com/author/johndoe/",
    "type": "Person",
    "preferredUsername": "johndoe",
    "name": "John Doe",
    "inbox": "https://example.com/wp-json/activitypub/1.0/users/1/inbox",
    "outbox": "https://example.com/wp-json/activitypub/1.0/users/1/outbox",
    "url": "https://example.com/author/johndoe/",
    "endpoints": {
        "sharedInbox": "https://example.com/wp-json/activitypub/1.0/inbox"
    },
    "publicKey": {
        "id": "https://example.com/author/johndoe/#main-key",
        "owner": "https://example.com/author/johndoe/",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
    },
    "attachment": [
        {
            "type": "PropertyValue",
            "name": "Blog",
            "value": "<a href=\\"https://example.com/\\">example.com</a>"
        },
        {
            "type": "Link",
            "name": "Blog",
            "href": "https://example.com/",
            "rel": ["me", "noopener"]
        },
        {
            "type": "PropertyValue",
            "name": "GitHub",
            "value": "<a href=\\"https://github.com/johndoe\\">github.com/johndoe</a>"
        },
        {
            "type": "Link",
            "name": "GitHub",
            "href": "https://github.com/johndoe"
        }
    ]
}
"""

    let statusCase07 = """
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    {
      "ostatus": "http://ostatus.org#",
      "atomUri": "ostatus:atomUri",
      "inReplyToAtomUri": "ostatus:inReplyToAtomUri",
      "conversation": "ostatus:conversation",
      "sensitive": "as:sensitive",
      "toot": "http://joinmastodon.org/ns#",
      "votersCount": "toot:votersCount",
      "Emoji": "toot:Emoji",
      "focalPoint": {
        "@container": "@list",
        "@id": "toot:focalPoint"
      }
    }
  ],
  "id": "https://server.social/users/dduser/statuses/113842725657361890",
  "type": "Note",
  "summary": null,
  "inReplyTo": "https://server.social/users/dduser/statuses/113842720482789570",
  "published": "2025-01-17T08:22:17Z",
  "url": "https://server.social/@dduser/113842725657361890",
  "attributedTo": "https://server.social/users/dduser",
  "to": [
    "https://server.social/users/dduser/followers"
  ],
  "cc": [
    "https://www.w3.org/ns/activitystreams#Public",
    "https://server.social/users/ddkinga",
    "https://vernissage.social/actors/ddkinga"
  ],
  "sensitive": false,
  "atomUri": "https://server.social/users/dduser/statuses/113842725657361890",
  "inReplyToAtomUri": "https://server.social/users/dduser/statuses/113842720482789570",
  "conversation": "tag:pnpde.social,2025-01-16:objectId=7147498:objectType=Conversation",
  "content": "<p><span class=\\"h-card\\" translate=\\"no\\"><a href=\\"https://mastodon.pnpde.social/@kathaga\\" class=\\"u-url mention\\">@<span>kathaga</span></a></span> <span class=\\"h-card\\" translate=\\"no\\"><a href=\\"https://vernissage.pnpde.social/@kathaga\\" class=\\"u-url mention\\">@<span>kathaga@vernissage.pnpde.social</span></a></span> und nochmal mit Custom Emoji :KritischerTreffer:</p>",
  "contentMap": {
    "de": "<p><span class=\\"h-card\\" translate=\\"no\\"><a href=\\"https://mastodon.pnpde.social/@kathaga\\" class=\\"u-url mention\\">@<span>kathaga</span></a></span> <span class=\\"h-card\\" translate=\\"no\\"><a href=\\"https://vernissage.pnpde.social/@kathaga\\" class=\\"u-url mention\\">@<span>kathaga@vernissage.pnpde.social</span></a></span> und nochmal mit Custom Emoji :KritischerTreffer:</p>"
  },
  "attachment": [],
  "tag": [
    {
      "type": "Mention",
      "href": "https://server.social/users/ddkinga",
      "name": "@ddkinga"
    },
    {
      "type": "Mention",
      "href": "https://vernissage.social/actors/ddkinga",
      "name": "@ddkinga@vernissage.social"
    },
    {
      "id": "https://server.social/emojis/7421",
      "type": "Emoji",
      "name": ":KritischerTreffer:",
      "updated": "2023-02-13T22:09:22Z",
      "icon": {
        "type": "Image",
        "mediaType": "image/png",
        "url": "https://server.social/system/custom_emojis/images/000/007/421/original/350499e0e0477dd7.png"
      }
    }
  ],
  "replies": {
    "id": "https://server.social/users/dduser/statuses/113842725657361890/replies",
    "type": "Collection",
    "first": {
      "type": "CollectionPage",
      "next": "https://server.social/users/dduser/statuses/113842725657361890/replies?only_other_accounts=true&page=true",
      "partOf": "https://server.social/users/dduser/statuses/113842725657361890/replies",
      "items": []
    }
  },
  "likes": {
    "id": "https://server.social/users/dduser/statuses/113842725657361890/likes",
    "type": "Collection",
    "totalItems": 0
  },
  "shares": {
    "id": "https://server.social/users/dduser/statuses/113842725657361890/shares",
    "type": "Collection",
    "totalItems": 0
  }
}
"""
    
    let statusCase08 = """
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "https://purl.archive.org/miscellany"
  ],
  "attachment": [
    {
      "name": "A semaphore signal at Park South near Barrow-in-Furness.",
      "type": "Image",
      "url": "https://enoki.us-east.host.bsky.network/xrpc/com.atproto.sync.getBlob?did=did:plc:25pjv3klpvtyfupgodearyop&cid=bafkreie32hoe5ugeo3oj7g2vkyz74rgxq5s5yjq2fs7g62nnko33sllwcu"
    }
  ],
  "attributedTo": "https://bsky.brid.gy/ap/did:plc:25pjv3klpvtyfupgodearyop",
  "content": "<p>Semaphore at Park South. 20 December 2025. <a class=\\"hashtag\\" rel=\\"tag\\" href=\\"https://bsky.app/search?q=%23railway\\">#railway</a> <a class=\\"hashtag\\" rel=\\"tag\\" href=\\"https://bsky.app/search?q=%23photography\\">#photography</a></p>",
  "contentMap": {
    "en": "<p>Semaphore at Park South. 20 December 2025. <a class=\\"hashtag\\" rel=\\"tag\\" href=\\"https://bsky.app/search?q=%23railway\\">#railway</a> <a class=\\"hashtag\\" rel=\\"tag\\" href=\\"https://bsky.app/search?q=%23photography\\">#photography</a></p>"
  },
  "id": "https://bsky.brid.gy/convert/ap/at://did:plc:25pjv3klpvtyfupgodearyop/app.bsky.feed.post/3mhfimrpn5s2b",
  "image": {
    "name": "A semaphore signal at Park South near Barrow-in-Furness.",
    "type": "Image",
    "url": "https://enoki.us-east.host.bsky.network/xrpc/com.atproto.sync.getBlob?did=did:plc:25pjv3klpvtyfupgodearyop&cid=bafkreie32hoe5ugeo3oj7g2vkyz74rgxq5s5yjq2fs7g62nnko33sllwcu"
  },
  "published": "2026-03-19T07:37:53.911Z",
  "tag": [
    {
      "href": "https://bsky.app/search?q=%23railway",
      "name": "#railway",
      "type": "Hashtag"
    },
    {
      "href": "https://bsky.app/search?q=%23photography",
      "name": "#photography",
      "type": "Hashtag"
    }
  ],
  "to": [
    "https://www.w3.org/ns/activitystreams#Public"
  ],
  "type": "Note",
  "url": [
    "https://bsky.brid.gy/r/https://bsky.app/profile/did:plc:25pjv3klpvtyfupgodearyop/post/3mhfimrpn5s2b",
    {
      "href": "at://did:plc:25pjv3klpvtyfupgodearyop/app.bsky.feed.post/3mhfimrpn5s2b",
      "rel": "canonical",
      "type": "Link"
    }
  ]
}
"""
    
    private let personCase11 =
"""
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "https://w3id.org/security/v1"
  ],
  "type": "Service",
  "id": "https://relay.fedi.buzz/tag/52challenge",
  "name": "#52challenge",
  "icon": {
    "type": "Image",
    "mediaType": "image/jpeg",
    "url": "https://fedi.buzz/assets/favicon48.png"
  },
  "inbox": "https://relay.fedi.buzz/tag/52challenge",
  "outbox": "https://relay.fedi.buzz/tag/52challenge/outbox",
  "endpoints": {
    "sharedInbox": "https://relay.fedi.buzz/instance/relay.fedi.buzz"
  },
  "publicKey": {
    "id": "https://relay.fedi.buzz/tag/52challenge#key",
    "owner": "https://relay.fedi.buzz/tag/52challenge",
    "publicKeyPem": "-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
  },
  "preferredUsername": "tag-52challenge"
}
"""
    
    private let personCase12 =
"""
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "https://w3id.org/security/v1"
  ],
  "id": "https://bsky.brid.gy/ap/did:plc:3ljmtyyjqcjee2kpewgsifvb",
  "type": "Person",
  "preferredUsername": "snarfed",
  "name": "Ryan Barrett",
  "summary": "<p>Twórca Bridgy. Piszę o decentralizacji.</p>",
  "url": "https://bsky.app/profile/snarfed.bsky.social",
  "alsoKnownAs": [
    "at://did:plc:3ljmtyyjqcjee2kpewgsifvb"
  ],
  "inbox": "https://bsky.brid.gy/ap/did:plc:3ljmtyyjqcjee2kpewgsifvb/inbox",
  "outbox": "https://bsky.brid.gy/ap/did:plc:3ljmtyyjqcjee2kpewgsifvb/outbox",
  "followers": "https://bsky.brid.gy/ap/did:plc:3ljmtyyjqcjee2kpewgsifvb/followers",
  "following": "https://bsky.brid.gy/ap/did:plc:3ljmtyyjqcjee2kpewgsifvb/following",
  "publicKey": {
    "id": "https://bsky.brid.gy/ap/did:plc:3ljmtyyjqcjee2kpewgsifvb#main-key",
    "owner": "https://bsky.brid.gy/ap/did:plc:3ljmtyyjqcjee2kpewgsifvb",
        "publicKeyPem": "-----BEGIN PUBLIC KEY-----AAAAA-----END PUBLIC KEY-----"
  },
  "icon": {
    "type": "Image",
    "mediaType": "image/jpeg",
    "url": "https://example.cdn.bskycdn.com/avatar.jpg"
  },
  "manuallyApprovesFollowers": false
}
"""
    
    private let statusCase09 =
"""
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "https://purl.archive.org/miscellany",
    {
      "_misskey_quote": "https://misskey-hub.net/ns#_misskey_quote"
    }
  ],
  "_misskey_quote": "https://bsky.brid.gy/convert/ap/at://did:plc:hf7ezrajxadu7v3tzcyij424/app.bsky.feed.post/3mhg4guilx225",
  "attributedTo": "https://bsky.brid.gy/ap/did:plc:hf7ezrajxadu7v3tzcyij424",
  "content": "<p>Like.. come tf on, you cannot seriously argue that</p>",
  "contentMap": {
    "en": "<p>Like... come tf on, you cannot seriously argue that</p>"
  },
  "id": "https://bsky.brid.gy/convert/ap/at://did:plc:hf7ezrajxadu7v3tzcyij424/app.bsky.feed.post/3mhg4lxsz2s25",
  "inReplyTo": {
    "id": "https://bsky.brid.gy/convert/ap/at://did:plc:hf7ezrajxadu7v3tzcyij424/app.bsky.feed.post/3mhg4guilx225",
    "url": "https://bsky.app/profile/did:plc:hf7ezrajxadu7v3tzcyij424/post/3mhg4guilx225"
  },
  "published": "2026-03-19T13:35:21.598Z",
  "quoteUrl": "https://bsky.brid.gy/convert/ap/at://did:plc:hf7ezrajxadu7v3tzcyij424/app.bsky.feed.post/3mhg4guilx225",
  "tag": [
    {
      "name": "bsky.app/profile/park...",
      "type": "Article",
      "url": "https://bsky.app/profile/parkermolloy.com/post/3mhg4guilx225"
    },
    {
      "href": "https://bsky.brid.gy/convert/ap/at://did:plc:hf7ezrajxadu7v3tzcyij424/app.bsky.feed.post/3mhg4guilx225",
      "mediaType": "application/ld+json; profile=\\"https://www.w3.org/ns/activitystreams\\"",
      "name": "RE: https://bsky.app/profile/did:plc:hf7ezrajxadu7v3tzcyij424/post/3mhg4guilx225",
      "type": "Link"
    }
  ],
  "to": [
    "https://www.w3.org/ns/activitystreams#Public"
  ],
  "type": "Note",
  "url": [
    "https://bsky.brid.gy/r/https://bsky.app/profile/did:plc:hf7ezrajxadu7v3tzcyij424/post/3mhg4lxsz2s25",
    {
      "href": "at://did:plc:hf7ezrajxadu7v3tzcyij424/app.bsky.feed.post/3mhg4lxsz2s25",
      "rel": "canonical",
      "type": "Link"
    }
  ]
}
"""
    
    private let personCase13 =
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
    "tag": "https://example.com/tag",
    "type": "Person",
    "url": "https://example.com/@johndoe"
}
"""
    
    @Test
    func `JSON with person string should deserialize`() throws {

        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: personCase01.data(using: .utf8)!)

        // Assert.
        #expect(
            activityDto.actor == .single(ActorDto(id: "http://sally.example.org", type: nil)),
            "Single person name should deserialize correctly"
        )
    }
    
    @Test
    func `JSON with person string arrays should deserialize`() throws {

        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: personCase02.data(using: .utf8)!)

        // Assert.
        #expect(activityDto.actor == .multiple([
            ActorDto(id: "http://sallyA.example.org"),
            ActorDto(id: "http://sallyB.example.org")
        ]), "Multiple person name should deserialize correctly")
    }
    
    @Test
    func `JSON with person object should deserialize`() throws {

        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: personCase03.data(using: .utf8)!)

        // Assert.
        #expect(
            activityDto.actor == .single(ActorDto(id: "http://sally.example.org", type: .person)),
            "Single person name should deserialize correctly"
        )
    }
    
    @Test
    func `JSON with person object arrays should deserialize`() throws {

        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: personCase04.data(using: .utf8)!)

        // Assert.
        #expect(activityDto.actor == .multiple([
            ActorDto(id: "http://sallyA.example.org", type: .person),
            ActorDto(id: "http://sallyB.example.org", type: .person)
        ]), "Multiple person name should deserialize correctly")
    }
    
    @Test
    func `JSON with person mixed arrays should deserialize`() throws {

        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: personCase05.data(using: .utf8)!)

        // Assert.
        #expect(activityDto.actor == .multiple([
            ActorDto(id: "http://sallyA.example.org"),
            ActorDto(id: "http://sallyB.example.org", type: .person)
        ]), "Multiple person name should deserialize correctly")
    }
    
    @Test
    func `JSON with person emojis should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: personCase06.data(using: .utf8)!)

        // Assert.
        #expect(personDto.tag?.tags().first?.name == ":verified:")
        #expect(personDto.tag?.tags().first?.type == .emoji)
    }
    
    @Test
    func `JSON with person emojis clear name should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: personCase06.data(using: .utf8)!)

        // Assert.
        #expect(personDto.clearName() == "John Doe")
    }

    @Test
    func `JSON with person fields should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: personCase07.data(using: .utf8)!)

        // Assert.
        #expect(personDto.attachment?[0].name == "MASTODON")
        #expect(personDto.attachment?[0].value == "https://mastodon.social/@johndoe")
        #expect(personDto.attachment?[0].type == "PropertyValue")
        
        #expect(personDto.attachment?[1].name == "GITHUB")
        #expect(personDto.attachment?[1].value == "https://github.com/johndoe")
        #expect(personDto.attachment?[1].type == "PropertyValue")
    }
    
    
    @Test
    func `JSON withouth manuallyApprovesFollowers field in person should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: personCase08.data(using: .utf8)!)

        // Assert.
        #expect(personDto.manuallyApprovesFollowers == false)
    }
    
    @Test
    func `JSON with complex properties from brid.gy should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: personCase09.data(using: .utf8)!)

        // Assert.
        #expect(personDto.manuallyApprovesFollowers == false)
    }

    @Test
    func `JSON with mixed PropertyValue and Link attachments should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: personCase10.data(using: .utf8)!)

        // Assert.
        #expect(personDto.attachment?.count == 4)

        #expect(personDto.attachment?[0].type == "PropertyValue")
        #expect(personDto.attachment?[0].name == "Blog")
        #expect(personDto.attachment?[0].value != nil)

        #expect(personDto.attachment?[1].type == "Link")
        #expect(personDto.attachment?[1].name == "Blog")
        #expect(personDto.attachment?[1].value == nil)

        #expect(personDto.attachment?[2].type == "PropertyValue")
        #expect(personDto.attachment?[2].name == "GitHub")
        #expect(personDto.attachment?[2].value != nil)

        #expect(personDto.attachment?[3].type == "Link")
        #expect(personDto.attachment?[3].name == "GitHub")
        #expect(personDto.attachment?[3].value == nil)
    }
    
    @Test
    func `Only flexi fields should be returned from deserialized object by flexiField function`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: personCase10.data(using: .utf8)!)

        // Assert.
        let flexiFields = personDto.flexiFields()
        #expect(flexiFields?.count == 2)
        
        #expect(flexiFields?[0].type == "PropertyValue")
        #expect(flexiFields?[0].name == "Blog")
        #expect(flexiFields?[0].value != nil)

        #expect(flexiFields?[1].type == "PropertyValue")
        #expect(flexiFields?[1].name == "GitHub")
        #expect(flexiFields?[1].value != nil)
    }
    
    @Test
    func `JSON with create status1 should deserialize`() throws {
        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: statusCase01.data(using: .utf8)!)

        // Assert.
        #expect(
            activityDto.id == "https://mastodon.social/users/mczachurski/statuses/111000972200397678/activity",
            "Create status id should deserialize correctly"
        )
    }
    
    @Test
    func `JSON with create status2 should deserialize`() throws {
        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: statusCase02.data(using: .utf8)!)

        // Assert.
        #expect(
            activityDto.id == "https://pixelfed.social/p/mczachurski/624592411232880406/activity",
            "Create status id should deserialize correctly"
        )
    }
    
    @Test
    func `JSON with create announce should deserialize`() throws {
        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: statusCase03.data(using: .utf8)!)

        // Assert.
        #expect(activityDto.id == "https://pixelfed.social/p/mczachurski/624586708985817828/activity", "Create announe id should deserialize correctly")
        #expect(activityDto.type == .announce, "Create announe type should deserialize correctly")
        #expect(activityDto.actor.actorIds().first == "https://pixelfed.social/users/mczachurski", "Create announe actor should deserialize correctly")
        #expect(activityDto.object.objects().first?.id == "https://mastodonapp.uk/@damianward/111322877716364793", "Create announe object should deserialize correctly")
    }
    
    @Test
    func `JSON with create announce and published should deserialize`() throws {
        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: statusCase04.data(using: .utf8)!)

        // Assert.
        #expect(activityDto.id == "https://mastodon.social/users/mczachurski/statuses/111330332088404363/activity", "Create announe id should deserialize correctly")
        #expect(activityDto.type == .announce, "Create announe type should deserialize correctly")
        #expect(activityDto.actor.actorIds().first == "https://mastodon.social/users/mczachurski", "Create announe actor should deserialize correctly")
        #expect(activityDto.object.objects().first?.id == "https://mastodon.social/users/TomaszSusul/statuses/111305598148116184", "Create announe object should deserialize correctly")
    }
    
    @Test
    func `JSON with create status5 should deserialize`() throws {
        // Act.
        let activityDto = try self.decoder.decode(ActivityDto.self, from: statusCase05.data(using: .utf8)!)

        // Assert.
        #expect(
            activityDto.id == "https://pixelfed.social/p/mczachurski/650595293594582993/activity",
            "Create status id should deserialize correctly"
        )
        
        let noteDto = activityDto.object.objects().first?.object as? NoteDto
        #expect(noteDto != nil, "Note should be deserialized")
    }
    
    @Test
    func `JSON with custom emoji should deserialize`() throws {
        // Act.
        let noteDto = try self.decoder.decode(NoteDto.self, from: statusCase07.data(using: .utf8)!)

        // Assert.
        #expect(noteDto.id == "https://server.social/users/dduser/statuses/113842725657361890", "Note id should deserialize correctly")
        #expect(noteDto.tag?.emojis().first != nil , "Emoji should be deserialized")
        #expect(noteDto.tag?.emojis().first?.name == ":KritischerTreffer:", "Emoji name should be deserialized")
        #expect(noteDto.tag?.emojis().first?.icon?.url == "https://server.social/system/custom_emojis/images/000/007/421/original/350499e0e0477dd7.png", "Emoji url should be deserialized")
    }
    
    @Test
    func `JSON from bsky.brid.gy should deserialize`() throws {
        // Act.
        let noteDto = try self.decoder.decode(NoteDto.self, from: statusCase08.data(using: .utf8)!)

        // Assert.
        #expect(noteDto.id == "https://bsky.brid.gy/convert/ap/at://did:plc:25pjv3klpvtyfupgodearyop/app.bsky.feed.post/3mhfimrpn5s2b", "Note id should deserialize correctly")
        #expect(noteDto.url == "https://bsky.brid.gy/r/https://bsky.app/profile/did:plc:25pjv3klpvtyfupgodearyop/post/3mhfimrpn5s2b", "Property 'url' is not valid.")
    }
    
    @Test
    func `JSON with person but without url string should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: personCase11.data(using: .utf8)!)

        // Assert.
        #expect(personDto.id == "https://relay.fedi.buzz/tag/52challenge" , "Pserson id should deserialize.")
        #expect(personDto.url == nil, "Url should be nil when it's not exists in the JSON.")
    }
    
    @Test
    func `JSON with person from bluesky bridge should deserialize`() throws {

        // Act.
        let personDto = try self.decoder.decode(PersonDto.self, from: personCase12.data(using: .utf8)!)

        // Assert.
        #expect(personDto.id == "https://bsky.brid.gy/ap/did:plc:3ljmtyyjqcjee2kpewgsifvb" , "Pserson id should deserialize.")
        #expect(personDto.url?.values().first == "https://bsky.app/profile/snarfed.bsky.social", "Url should be nil when it's not exists in the JSON.")
    }
    
    @Test
    func `JSON from bsky.brid.gy with complex inReplyTo should deserialize`() throws {
        // Act.
        let noteDto = try self.decoder.decode(NoteDto.self, from: statusCase09.data(using: .utf8)!)

        // Assert.
        #expect(noteDto.id == "https://bsky.brid.gy/convert/ap/at://did:plc:hf7ezrajxadu7v3tzcyij424/app.bsky.feed.post/3mhg4lxsz2s25", "Note id should deserialize correctly")
        #expect(noteDto.inReplyTo == "https://bsky.brid.gy/convert/ap/at://did:plc:hf7ezrajxadu7v3tzcyij424/app.bsky.feed.post/3mhg4guilx225", "Property 'inReplyTo' is not valid.")
    }
    
    @Test
    func `JSON with person string and tag as s string should deserialize`() throws {

        // Act.
        let activityDto = try self.decoder.decode(PersonDto.self, from: personCase13.data(using: .utf8)!)

        // Assert.
        #expect(
            activityDto.tag == .single(PersonHashtagDto(type: .unknown, name: "https://example.com/tag")),
            "Single person name should deserialize correctly"
        )
    }
}

