//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import JWT
import ActivityPubKit

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
    
    func testJsonWithPersonStringShouldDeserialize() throws {

        // Act.
        let activityDto = try JSONDecoder().decode(ActivityDto.self, from: personCase01.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(
            activityDto.actor,
            .single(BaseActorDto(id: "http://sally.example.org", type: .person)),
            "Single person name should deserialize correctly"
        )
    }
    
    func testJsonWithPersonStringArraysShouldDeserialize() throws {

        // Act.
        let activityDto = try JSONDecoder().decode(ActivityDto.self, from: personCase02.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(activityDto.actor, .multiple([
            BaseActorDto(id: "http://sallyA.example.org", type: .person),
            BaseActorDto(id: "http://sallyB.example.org", type: .person)
        ]), "Multiple person name should deserialize correctly")
    }
    
    func testJsonWithPersonObjectShouldDeserialize() throws {

        // Act.
        let activityDto = try JSONDecoder().decode(ActivityDto.self, from: personCase03.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(
            activityDto.actor,
            .single(BaseActorDto(id: "http://sally.example.org", type: .person)),
            "Single person name should deserialize correctly"
        )
    }
    
    func testJsonWithPersonObjectArraysShouldDeserialize() throws {

        // Act.
        let activityDto = try JSONDecoder().decode(ActivityDto.self, from: personCase04.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(activityDto.actor, .multiple([
            BaseActorDto(id: "http://sallyA.example.org", type: .person),
            BaseActorDto(id: "http://sallyB.example.org", type: .person)
        ]), "Multiple person name should deserialize correctly")
    }
    
    func testJsonWithPersonMixedArraysShouldDeserialize() throws {

        // Act.
        let activityDto = try JSONDecoder().decode(ActivityDto.self, from: personCase04.data(using: .utf8)!)

        // Assert.
        XCTAssertEqual(activityDto.actor, .multiple([
            BaseActorDto(id: "http://sallyA.example.org", type: .person),
            BaseActorDto(id: "http://sallyB.example.org", type: .person)
        ]), "Multiple person name should deserialize correctly")
    }
}

