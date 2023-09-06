//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import XCTest
@testable import ActivityPubKit

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
{"@context":"https:\\/\\/www.w3.org\\/ns\\/activitystreams","actor":{"id":"https:\\/\\/example.com\\/actor-a","name":null,"type":"Person"},"id":"https:\\/\\/example.com\\/actor-a#1234","object":{"actor":null,"id":"https:\\/\\/example.com\\/actor-b","name":null,"object":null,"to":null,"type":"Profile"},"type":"Follow"}
"""
        XCTAssertEqual(expectedJSON, String(data: jsonData, encoding: .utf8)!)
    }
}
