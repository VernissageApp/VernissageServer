//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Testing

@Suite("String optional tests")
struct StringOptionalTests {

    @Test
    func `Nil if empty or whitespace should return nil for empty strings`() async throws {
        // Assert.
        #expect("".nilIfEmptyOrWhitespace == nil, "Empty string should be returned as nil.")
        #expect("   ".nilIfEmptyOrWhitespace == nil, "Whitespace string should be returned as nil.")
    }

    @Test
    func `Nil if empty or whitespace should return trimmed string`() async throws {
        // Assert.
        #expect("  en_us  ".nilIfEmptyOrWhitespace == "en_us", "Trimmed string should be returned.")
    }
}
