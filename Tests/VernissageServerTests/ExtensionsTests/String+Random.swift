//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Testing
import Foundation

@Suite("String random tests")
struct StringRandomTests {
    
    @Test
    func `Randomed string should have a correct length.`() async throws {
        // Act.
        let randomString = String.createRandomString(length: 10)
        
        // Arrange.
        #expect(randomString.count == 10)
    }
}
