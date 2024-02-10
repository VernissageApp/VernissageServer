//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class StringHashtagsTests: XCTestCase {
    
    func testArrayOfHashtagsShouldBeEmptyWhenStringNotContainAnyHashtags() async throws {
        
        // Arrange.
        let content = "This is content without hashtags"
        
        // Act.
        let hashtags = content.getHashtags()
        
        // Assert.
        XCTAssertTrue(hashtags.isEmpty, "Array should be empty")
    }
    
    func testArrayOfHashtagsShouldContainHastagsWhenStringContainsHashtags() async throws {
        
        // Arrange.
        let content = "This is content without hashtags #black #white"
        
        // Act.
        let hashtags = content.getHashtags()
        
        // Assert.
        XCTAssertEqual(hashtags.count, 2, "Array should contain two hashtags")
        XCTAssertTrue(hashtags.contains("black"), "Array should contain black hashtag")
        XCTAssertTrue(hashtags.contains("white"), "Array should contain white hashtag")
    }
    
    func testArrayOfHashtagsShouldContainUniqueHastagsWhenStringContainsDuplicatedHashtags() async throws {
        
        // Arrange.
        let content = "This is content without hashtags #black #white #Black #BLACK"
        
        // Act.
        let hashtags = content.getHashtags()
        
        // Assert.
        XCTAssertEqual(hashtags.count, 2, "Array should contain two hashtags")
        XCTAssertTrue(hashtags.contains("black"), "Array should contain black hashtag")
        XCTAssertTrue(hashtags.contains("white"), "Array should contain white hashtag")
    }
}
