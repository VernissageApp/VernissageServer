//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Testing

@Suite("String hashtags tests")
struct StringHashtagsTests {
    
    @Test
    func `Array of hashtags should be empty when string not contain any hashtags`() async throws {
        
        // Arrange.
        let content = "This is content without hashtags"
        
        // Act.
        let hashtags = content.getHashtags()
        
        // Assert.
        #expect(hashtags.isEmpty, "Array should be empty")
    }
    
    @Test
    func `Array of hashtags should contain hastags when string contains hashtags`() async throws {
        
        // Arrange.
        let content = "This is content without hashtags #black #white"
        
        // Act.
        let hashtags = content.getHashtags()
        
        // Assert.
        #expect(hashtags.count == 2, "Array should contain two hashtags")
        #expect(hashtags.contains("black"), "Array should contain black hashtag")
        #expect(hashtags.contains("white"), "Array should contain white hashtag")
    }
    
    @Test
    func `Array of hashtags should contain unique hastags when string contains duplicated hashtags`() async throws {
        
        // Arrange.
        let content = "This is content without hashtags #black #white #Black #BLACK"
        
        // Act.
        let hashtags = content.getHashtags()
        
        // Assert.
        #expect(hashtags.count == 2, "Array should contain two hashtags")
        #expect(hashtags.contains("black"), "Array should contain black hashtag")
        #expect(hashtags.contains("white"), "Array should contain white hashtag")
    }
    
    @Test
    func `Hashtag with special characters should be recognized`() async throws {
        
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
