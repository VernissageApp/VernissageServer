//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Testing

@Suite("String HTML tests")
struct StringHtmlTests {

    @Test
    func `Rendering single username`() async throws {
        
        // Arrange.
        let text = "@marcin OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p><a href="https://vernissage.com/@marcin" class="username" target="_blank">@marcin</a> OK</p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test
    func `Rendering single url address`() async throws {
        
        // Arrange.
        let text = "@marcin@other.uk OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p><a href="https://other.uk/@marcin" class="username" target="_blank">@marcin@other.uk</a> OK</p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test
    func `Rendering single url address with dot`() async throws {
        
        // Arrange.
        let text = "@marcin.test@other.uk Comment test"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p><a href="https://other.uk/@marcin.test" class="username" target="_blank">@marcin.test@other.uk</a> Comment test</p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test
    func `Rendering single url address with dot at the end of sentance`() async throws {
        
        // Arrange.
        let text = "Here is the user @marcin.test@other.uk."
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p>Here is the user <a href="https://other.uk/@marcin.test" class="username" target="_blank">@marcin.test@other.uk</a>.</p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test
    func `Rendering single url with text address`() async throws {
        
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
    
    @Test
    func `Rendering single url with text and parentheses`() async throws {
        
        // Arrange.
        let text = "Look here (https://mastodon.social/) OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p>Look here (<a href="https://mastodon.social/" rel="me nofollow noopener noreferrer" class="url" target="_blank"><span class="invisible">https://</span>mastodon.social/</a>) OK</p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test
    func `Rendering single hashtag`() async throws {
        
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
    
    @Test
    func `Rendering single hashtag without prefix text`() async throws {
        
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

    @Test
    func `Rendering with new lines`() async throws {
        
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
<p>This status for <a href="https://vernissage.com/@wify" class="username" target="_blank">@wify</a>.<br /><br /><a href="https://vernissage.com/tags/street" rel="tag" class="mention hashtag">#street</a> <a href="https://vernissage.com/tags/photo" rel="tag" class="mention hashtag">#photo</a> <a href="https://vernissage.com/tags/blackAndWwhite" rel="tag" class="mention hashtag">#blackAndWwhite</a></p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test
    func `Rendering all`() async throws {
        
        // Arrange.
        let text = "This is #hashtag for @marcin and https://test.com and #street for @marta@mastodon.social and https://ap.com OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p>This is <a href="https://vernissage.com/tags/hashtag" rel="tag" class="mention hashtag">#hashtag</a> for <a href="https://vernissage.com/@marcin" class=\"username\" target="_blank">@marcin</a> and <a href="https://test.com" rel="me nofollow noopener noreferrer" class="url" target="_blank"><span class="invisible">https://</span>test.com</a> and <a href="https://vernissage.com/tags/street" rel="tag" class="mention hashtag">#street</a> for <a href="https://mastodon.social/@marta" class=\"username\" target="_blank">@marta@mastodon.social</a> and <a href="https://ap.com" rel="me nofollow noopener noreferrer" class="url" target="_blank"><span class="invisible">https://</span>ap.com</a> OK</p>
"""
        #expect(html == expectedHtml)
    }
    
    @Test
    func `Rendering single url with user name`() async throws {
        
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
    
    @Test
    func `Rendering single url without paragraph`() async throws {
        
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
    
    @Test
    func `Rendering text with hashtags with accents`() async throws {
        
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
    
    @Test
    func `Rendering simple markdown to HTML`() async throws {
        
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
    
    @Test
    func `Rendering complex text with hashtags to html should add anchors`() async throws {

        // Arrange.
        let text = "Zwischen Wurzeln und Freiheit\r\n\r\nIm Tanz zwischen Schatten und Stille erinnert der Wald daran, dass Freiheit dort beginnt, wo der Mensch den Mut findet, sich selbst loszulassen und ganz im Augenblick zu sein. 🖤✨\r\n\r\nModel: Goldie\r\n----------------------------------\r\n#SoulGaze\r\n#MoodPortraits\r\n#outdoorshooting\r\n#selflove\r\n#soul2soul\r\n#analog\r\n#analogvibes\r\n#bnwportraits\r\n#bnwportrait\r\n#bnw_portrait\r\n#photos\r\n#portraitgermany\r\n#portraitphotography\r\n#nude\r\n#portrait_bnw\r\n#tfpgermany\r\n#nrw\r\n#Krefeld\r\n#tfpnrw\r\n#tfpshooting"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com", wrapInParagraph: true)
        
        // Assert.
        let expectedHtml =
"""
<p>Zwischen Wurzeln und Freiheit<br /><br />Im Tanz zwischen Schatten und Stille erinnert der Wald daran, dass Freiheit dort beginnt, wo der Mensch den Mut findet, sich selbst loszulassen und ganz im Augenblick zu sein. 🖤✨<br /><br />Model: Goldie<br />----------------------------------<br /><a href="https://vernissage.com/tags/SoulGaze" rel="tag" class="mention hashtag">#SoulGaze</a><br /><a href="https://vernissage.com/tags/MoodPortraits" rel="tag" class="mention hashtag">#MoodPortraits</a><br /><a href="https://vernissage.com/tags/outdoorshooting" rel="tag" class="mention hashtag">#outdoorshooting</a><br /><a href="https://vernissage.com/tags/selflove" rel="tag" class="mention hashtag">#selflove</a><br /><a href="https://vernissage.com/tags/soul2soul" rel="tag" class="mention hashtag">#soul2soul</a><br /><a href="https://vernissage.com/tags/analog" rel="tag" class="mention hashtag">#analog</a><br /><a href="https://vernissage.com/tags/analogvibes" rel="tag" class="mention hashtag">#analogvibes</a><br /><a href="https://vernissage.com/tags/bnwportraits" rel="tag" class="mention hashtag">#bnwportraits</a><br /><a href="https://vernissage.com/tags/bnwportrait" rel="tag" class="mention hashtag">#bnwportrait</a><br /><a href="https://vernissage.com/tags/bnw_portrait" rel="tag" class="mention hashtag">#bnw_portrait</a><br /><a href="https://vernissage.com/tags/photos" rel="tag" class="mention hashtag">#photos</a><br /><a href="https://vernissage.com/tags/portraitgermany" rel="tag" class="mention hashtag">#portraitgermany</a><br /><a href="https://vernissage.com/tags/portraitphotography" rel="tag" class="mention hashtag">#portraitphotography</a><br /><a href="https://vernissage.com/tags/nude" rel="tag" class="mention hashtag">#nude</a><br /><a href="https://vernissage.com/tags/portrait_bnw" rel="tag" class="mention hashtag">#portrait_bnw</a><br /><a href="https://vernissage.com/tags/tfpgermany" rel="tag" class="mention hashtag">#tfpgermany</a><br /><a href="https://vernissage.com/tags/nrw" rel="tag" class="mention hashtag">#nrw</a><br /><a href="https://vernissage.com/tags/Krefeld" rel="tag" class="mention hashtag">#Krefeld</a><br /><a href="https://vernissage.com/tags/tfpnrw" rel="tag" class="mention hashtag">#tfpnrw</a><br /><a href="https://vernissage.com/tags/tfpshooting" rel="tag" class="mention hashtag">#tfpshooting</a></p>
"""
        #expect(html == expectedHtml)
    }
}
