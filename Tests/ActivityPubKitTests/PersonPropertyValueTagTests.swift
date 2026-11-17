//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Foundation
import Testing

@Suite("Person property value tags")
struct PersonPropertyValueTagTests {
    @Test
    func `Hubzilla actor with protocol metadata should decode`() throws {
        // Arrange
        let data = Data(Self.hubzillaActor.utf8)

        // Act
        let person = try JSONDecoder().decode(PersonDto.self, from: data)

        // Assert
        #expect(person.id == "https://klacker.org/channel/steel_virgin")
        #expect(person.preferredUsername == "steel_virgin")
        #expect(person.inbox == "https://klacker.org/inbox/steel_virgin")
        #expect(person.tag?.tags() == [
            PersonHashtagDto(type: .propertyValue, name: "Protocol", value: "zot6"),
            PersonHashtagDto(type: .propertyValue, name: "Protocol", value: "activitypub")
        ])
        #expect(person.clearName() == "Daniel Cooper")
    }

    @Test(arguments: [false, true])
    func `Property value tag should decode as single object or mixed array`(multiple: Bool) throws {
        // Arrange
        let property = #"{"type":"PropertyValue","name":"Protocol","value":"activitypub"}"#
        let json = multiple
            ? "[\(property)," + ##"{"type":"Hashtag","name":"#photo","href":"https://example.com/tags/photo"},{"type":"Emoji","name":":camera:"}]"##
            : property

        // Act
        let tags = try JSONDecoder().decode(ComplexType<PersonHashtagDto>.self, from: Data(json.utf8)).tags()

        // Assert
        #expect(tags.first == PersonHashtagDto(type: .propertyValue, name: "Protocol", value: "activitypub"))
        if multiple {
            #expect(tags.map(\.type) == [.propertyValue, .hashtag, .emoji])
        } else {
            #expect(tags.count == 1)
        }
    }

    @Test
    func `Property value tag should preserve metadata when encoded`() throws {
        // Arrange
        let tag = PersonHashtagDto(type: .propertyValue, name: "Protocol", value: "zot6")

        // Act
        let data = try JSONEncoder().encode(tag)
        let decoded = try JSONDecoder().decode(PersonHashtagDto.self, from: data)

        // Assert
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(object == ["type": "PropertyValue", "name": "Protocol", "value": "zot6"])
        #expect(decoded == tag)
        #expect(tag != PersonHashtagDto(type: .propertyValue, name: "Protocol", value: "activitypub"))
    }

    @Test(arguments: ["Hashtag", "Mention", "Emoji", "Unknown"], ["42", "true", "{}", "[]", "\"text\"", "null"])
    func `Existing tag types should ignore unrelated value fields`(type: String, value: String) throws {
        // Arrange
        let json = """
        {"type":"\(type)","name":"tag","href":"https://example.com/tag","value":\(value)}
        """

        // Act
        let tag = try JSONDecoder().decode(PersonHashtagDto.self, from: Data(json.utf8))

        // Assert
        #expect(tag.type.rawValue == type)
        #expect(tag.name == "tag")
        #expect(tag.href == "https://example.com/tag")
        #expect(tag.value == nil)
    }

    private static let hubzillaActor = #"""
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "https://w3id.org/security/v1",
    "https://purl.archive.org/socialweb/webfinger",
    {
      "zot": "https://klacker.org/apschema#",
      "contextHistory": "https://w3id.org/fep/171b/contextHistory",
      "schema": "http://schema.org#",
      "ostatus": "http://ostatus.org#",
      "diaspora": "https://diasporafoundation.org/ns/",
      "litepub": "http://litepub.social/ns#",
      "toot": "http://joinmastodon.org/ns#",
      "commentPolicy": "zot:commentPolicy",
      "Bookmark": "zot:Bookmark",
      "Category": "zot:Category",
      "Emoji": "toot:Emoji",
      "directMessage": "litepub:directMessage",
      "PropertyValue": "schema:PropertyValue",
      "value": "schema:value",
      "uuid": "schema:identifier",
      "conversation": "ostatus:conversation",
      "manuallyApprovesFollowers": "as:manuallyApprovesFollowers",
      "Hashtag": "as:Hashtag",
      "quoteUrl": "as:quoteUrl",
      "quoteUri": "http://fedibird.com/ns#quoteUri"
    }
  ],
  "type": "Person",
  "manuallyApprovesFollowers": false,
  "id": "https://klacker.org/channel/steel_virgin",
  "preferredUsername": "steel_virgin",
  "name": "Daniel Cooper",
  "updated": "2026-10-26T07:08:50Z",
  "icon": {
    "type": "Image",
    "mediaType": "image/png",
    "updated": "2025-01-14T03:38:24Z",
    "url": "https://klacker.org/photo/profile/l/71?rev=1736822304",
    "height": 300,
    "width": 300
  },
  "url": "https://klacker.org/channel/steel_virgin",
  "publicKey": {
    "id": "https://klacker.org/channel/steel_virgin",
    "owner": "https://klacker.org/channel/steel_virgin",
    "signatureAlgorithm": "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256",
    "publicKeyPem": "test-public-key"
  },
  "tag": [
    {
      "type": "PropertyValue",
      "name": "Protocol",
      "value": "zot6"
    },
    {
      "type": "PropertyValue",
      "name": "Protocol",
      "value": "activitypub"
    }
  ],
  "outbox": "https://klacker.org/outbox/steel_virgin",
  "webfinger": "steel_virgin@klacker.org",
  "inbox": "https://klacker.org/inbox/steel_virgin",
  "followers": "https://klacker.org/followers/steel_virgin",
  "following": "https://klacker.org/following/steel_virgin",
  "endpoints": {
    "sharedInbox": "https://klacker.org/inbox"
  },
  "discoverable": true,
  "image": {
    "type": "Image",
    "mediaType": "image/png",
    "url": "https://klacker.org/photo/ca6ea1cd-bc93-4bfc-9b8b-1b3f52a058d5-7"
  }
}
"""#
}
