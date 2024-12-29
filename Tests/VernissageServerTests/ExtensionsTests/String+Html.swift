//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Testing

@Suite("String HTML tests")
struct StringHtmlTests {

    @Test("Rendering single username")
    func renderingSingleUsername() async throws {
        
        // Arrange.
        let text = "@marcin OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p><a href="https://vernissage.com/@marcin" class="username">@marcin</a> OK</p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test("Rendering single url address")
    func renderingSingleUrlAddress() async throws {
        
        // Arrange.
        let text = "@marcin@other.uk OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p><a href="https://other.uk/@marcin" class="username">@marcin@other.uk</a> OK</p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test("Rendering single url with text address")
    func renderingSingleUrlWithTextAddress() async throws {
        
        // Arrange.
        let text = "Look here https://mastodon.social/ OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p>Look here <a href="https://mastodon.social/" rel="me nofollow noopener noreferrer" class="url" target="_blank"><span class="invisible">https://</span>mastodon.social/</a> OK</p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test("Rendering single hashtag")
    func renderingSingleHashtag() async throws {
        
        // Arrange.
        let text = "This is #hashtag OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p>This is <a href="https://vernissage.com/tags/hashtag" rel="tag" class="mention hashtag">#hashtag</a> OK</p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test("Rendering single hashtag without prefix text")
    func renderingSingleHashtagWithoutPrefixText() async throws {
        
        // Arrange.
        let text = "#hashtag OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p><a href="https://vernissage.com/tags/hashtag" rel="tag" class="mention hashtag">#hashtag</a> OK</p>
"""
        #expect(html == expectedHtml)
    }

    @Test("Rendering with nee lines")
    func renderingWithNewLines() async throws {
        
        // Arrange.
        let text = """
This status for @wify.

#street #photo #blackAndWwhite
"""
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p>This status for <a href="https://vernissage.com/@wify" class="username">@wify</a>.<br /><br /><a href="https://vernissage.com/tags/street" rel="tag" class="mention hashtag">#street</a> <a href="https://vernissage.com/tags/photo" rel="tag" class="mention hashtag">#photo</a> <a href="https://vernissage.com/tags/blackAndWwhite" rel="tag" class="mention hashtag">#blackAndWwhite</a></p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test("Rendering all")
    func renderingAll() async throws {
        
        // Arrange.
        let text = "This is #hashtag for @marcin and https://test.com and #street for @marta@mastodon.social and https://ap.com OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p>This is <a href="https://vernissage.com/tags/hashtag" rel="tag" class="mention hashtag">#hashtag</a> for <a href="https://vernissage.com/@marcin" class=\"username\">@marcin</a> and <a href="https://test.com" rel="me nofollow noopener noreferrer" class="url" target="_blank"><span class="invisible">https://</span>test.com</a> and <a href="https://vernissage.com/tags/street" rel="tag" class="mention hashtag">#street</a> for <a href="https://mastodon.social/@marta" class=\"username\">@marta@mastodon.social</a> and <a href="https://ap.com" rel="me nofollow noopener noreferrer" class="url" target="_blank"><span class="invisible">https://</span>ap.com</a> OK</p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test("Rendering single url with user name")
    func renderingSingleUrlWithUserName() async throws {
        
        // Arrange.
        let text = "Look here https://mastodon.social/@marcin please"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p>Look here <a href="https://mastodon.social/@marcin" rel="me nofollow noopener noreferrer" class="url" target="_blank"><span class="invisible">https://</span>mastodon.social/@marcin</a> please</p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test("Rendering single url without paragraph")
    func renderingSingleUrlWithoutParagraps() async throws {
        
        // Arrange.
        let text = "https://example.test"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: false)
        
        // Assert.
        let expectedHtml =
"""
<a href="https://example.test" rel="me nofollow noopener noreferrer" class="url" target="_blank"><span class="invisible">https://</span>example.test</a>
"""
        #expect(html == expectedHtml)
    }
    
    @Test("Rendering text with hashtags with accents")
    func renderingTextWithHastagsWithAccents() async throws {
        
        // Arrange.
        let text = "This is content without hashtags #palazzodellaciviltàltaliana #zażółć #gëślå #jaźń #year2024_test"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p>This is content without hashtags <a href="https://vernissage.com/tags/palazzodellaciviltàltaliana" rel="tag" class="mention hashtag">#palazzodellaciviltàltaliana</a> <a href="https://vernissage.com/tags/zażółć" rel="tag" class="mention hashtag">#zażółć</a> <a href="https://vernissage.com/tags/gëślå" rel="tag" class="mention hashtag">#gëślå</a> <a href="https://vernissage.com/tags/jaźń" rel="tag" class="mention hashtag">#jaźń</a> <a href="https://vernissage.com/tags/year2024_test" rel="tag" class="mention hashtag">#year2024_test</a></p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test("Rendering simple markdown to HTML")
    func renderSimpleMarkdownToHtml() async throws {
        
        // Arrange.
        let text = "Test **bold** *italic*"
        
        // Act.
        let html = text.markdownHtml(baseAddress: "https://vernissage.com")
        
        // Assert.
        let expectedHtml =
"""
<p>Test <strong>bold</strong> <em>italic</em></p>
"""
        #expect(html == expectedHtml)
    }
}
