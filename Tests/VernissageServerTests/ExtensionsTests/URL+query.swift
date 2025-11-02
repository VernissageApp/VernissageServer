//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Testing
import Foundation

@Suite("URL query tests")
struct UrlQueryTests {
    
    @Test
    func `Correct query param value should be extracted from url.`() async throws {
        // Arrange.
        let url = URL(string: "https://test.com/test.png?querya=1&queryb=2")!
        
        // Act.
        let queryValue = url.valueOf("querya")
        
        // Arrange.
        #expect(queryValue == "1")
    }
}
