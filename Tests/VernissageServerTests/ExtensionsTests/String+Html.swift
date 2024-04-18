//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class StringHtmlTests: XCTestCase {

    func testRenderingSingleUsername() async throws {
        
        // Arrange.
        let text = "@marcin OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com")
        
        // Assert.
        let expectedHtml =
"""
<p><a href="https://vernissage.com/@marcin">@marcin</a> OK</p>
"""
        XCTAssertEqual(html, expectedHtml)
    }
    
    func testSomething2() async throws {
        
        // Arrange.
        let text = "@marcin@other.uk OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com")
        
        // Assert.
        let expectedHtml =
"""
<p><a href="https://other.uk/@marcin">@marcin@other.uk</a> OK</p>
"""
        XCTAssertEqual(html, expectedHtml)
    }
    
    func testRenderingSingleUrlAddress() async throws {
        
        // Arrange.
        let text = "Look here https://mastodon.social/ OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com")
        
        // Assert.
        let expectedHtml =
"""
<p>Look here <a href="https://mastodon.social/" rel="me nofollow noopener noreferrer" class="url" target="_blank">https://mastodon.social/</a> OK</p>
"""
        XCTAssertEqual(html, expectedHtml)
    }
    
    func testRenderingSingleHashtag() async throws {
        
        // Arrange.
        let text = "This is #hashtag OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com")
        
        // Assert.
        let expectedHtml =
"""
<p>This is <a href="https://vernissage.com/tags/hashtag">#hashtag</a> OK</p>
"""
        XCTAssertEqual(html, expectedHtml)
    }
    
    func testRenderingAll() async throws {
        
        // Arrange.
        let text = "This is #hashtag for @marcin and https://test.com and #street for @marta@mastodon.social and https://ap.com OK"
        
        // Act.
        let html = text.html(baseAddress: "https://vernissage.com")
        
        // Assert.
        let expectedHtml =
"""
<p>This is <a href="https://vernissage.com/tags/hashtag">#hashtag</a> for <a href="https://vernissage.com/@marcin">@marcin</a> and <a href="https://test.com" rel="me nofollow noopener noreferrer" class="url" target="_blank">https://test.com</a> and <a href="https://vernissage.com/tags/street">#street</a> for <a href="https://mastodon.social/@marta">@marta@mastodon.social</a> and <a href="https://ap.com" rel="me nofollow noopener noreferrer" class="url" target="_blank">https://ap.com</a> OK</p>
"""
        XCTAssertEqual(html, expectedHtml)
    }
}
