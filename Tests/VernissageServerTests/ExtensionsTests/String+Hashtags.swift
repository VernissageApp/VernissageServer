//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Testing

@Suite("String hashtags tests")
struct StringHashtagsTests {
    
    @Test("Array of hashtags should be empty when string not contain any hashtags")
    func arrayOfHashtagsShouldBeEmptyWhenStringNotContainAnyHashtags() async throws {
        
        // Arrange.
        let content = "This is content without hashtags"
        
        // Act.
        let hashtags = content.getHashtags()
        
        // Assert.
        #expect(hashtags.isEmpty, "Array should be empty")
    }
    
    @Test("Array of hashtags should contain hastags when string contains hashtags")
    func arrayOfHashtagsShouldContainHastagsWhenStringContainsHashtags() async throws {
        
        // Arrange.
        let content = "This is content without hashtags #black #white"
        
        // Act.
        let hashtags = content.getHashtags()
        
        // Assert.
        #expect(hashtags.count == 2, "Array should contain two hashtags")
        #expect(hashtags.contains("black"), "Array should contain black hashtag")
        #expect(hashtags.contains("white"), "Array should contain white hashtag")
    }
    
    @Test("Array of hashtags should contain unique hastags when string contains duplicated hashtags")
    func testArrayOfHashtagsShouldContainUniqueHastagsWhenStringContainsDuplicatedHashtags() async throws {
        
        // Arrange.
        let content = "This is content without hashtags #black #white #Black #BLACK"
        
        // Act.
        let hashtags = content.getHashtags()
        
        // Assert.
        #expect(hashtags.count == 2, "Array should contain two hashtags")
        #expect(hashtags.contains("black"), "Array should contain black hashtag")
        #expect(hashtags.contains("white"), "Array should contain white hashtag")
    }
    
    @Test("Hashtag with special characters should be recognized")
    func hashtagWithSpecialCharactersShouldBeRecognized() async throws {
        
        // Arrange.
        let content = "This is content without hashtags #palazzodellaciviltàltaliana #zażółć #gëślå #jaźń #year2024_test"
        
        // Act.
        let hashtags = content.getHashtags()
        
        // Assert.
        #expect(hashtags.count == 5, "Array should contain two hashtags")
        #expect(hashtags.contains("palazzodellaciviltàltaliana"), "Array should contain black hashtag")
        #expect(hashtags.contains("zażółć"), "Array should contain black hashtag")
        #expect(hashtags.contains("gëślå"), "Array should contain white hashtag")
        #expect(hashtags.contains("jaźń"), "Array should contain white hashtag")
        #expect(hashtags.contains("year2024_test"), "Array should contain white hashtag")
    }
}
