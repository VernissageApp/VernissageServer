//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import XCTest
@testable import ActivityPubKit

final class ActivityDtoSerialization: XCTestCase {
    func testActivityShouldSerializeWithSimpleSingleStrings() throws {
        let activityDto = ActivityDto(context: .single("https://www.w3.org/ns/activitystreams"),
                                      type: .follow,
                                      id: "https://example.com/actor-a#1234",
                                      actor: .single(.string("https://example.com/actor-a")),
                                      to: nil,
                                      object: .single(.string("https://example.com/actor-b")),
                                      summary: nil,
                                      signature: nil)
        
        let jsonData = try JSONEncoder().encode(activityDto)
        
        let expectedJSON = """
{"id":"https:\\/\\/example.com\\/actor-a#1234","object":"https:\\/\\/example.com\\/actor-b","@context":"https:\\/\\/www.w3.org\\/ns\\/activitystreams","type":"Follow","actor":"https:\\/\\/example.com\\/actor-a"}
"""
        XCTAssertEqual(expectedJSON, String(data: jsonData, encoding: .utf8)!)
    }
    
    func testActivityShouldSerializeWithSingleObjects() throws {
        let activityDto = ActivityDto(context: .single("https://www.w3.org/ns/activitystreams"),
                                      type: .follow,
                                      id: "https://example.com/actor-a#1234",
                                      actor: .single(.object(BaseActorDto(id: "https://example.com/actor-a", type: .person))),
                                      to: nil,
                                      object: .single(.object(BaseObjectDto(id: "https://example.com/actor-b", type: .profile))),
                                      summary: nil,
                                      signature: nil)
        
        let jsonData = try JSONEncoder().encode(activityDto)
        
        let expectedJSON = """
{"id":"https:\\/\\/example.com\\/actor-a#1234","object":{"id":"https:\\/\\/example.com\\/actor-b","to":null,"actor":null,"type":"Profile","name":null,"object":null},"@context":"https:\\/\\/www.w3.org\\/ns\\/activitystreams","type":"Follow","actor":{"id":"https:\\/\\/example.com\\/actor-a","type":"Person","name":null}}
"""
        XCTAssertEqual(expectedJSON, String(data: jsonData, encoding: .utf8)!)
    }
}
