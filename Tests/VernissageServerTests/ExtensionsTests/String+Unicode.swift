//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Testing

@Suite("String Unicode tests")
struct StringUnicodeTests {
    @Test(arguments: [
        ("Hello", 3, "Hel"),
        ("Hello", 20, "Hello"),
        ("", 200, ""),
        ("Hello", 0, ""),
        ("Hello", -1, ""),
        ("🇵🇱🇵🇱", 3, "🇵🇱"),
        ("👨‍👩‍👧‍👦!", 6, ""),
        ("👨‍👩‍👧‍👦!", 7, "👨‍👩‍👧‍👦"),
        ("e\u{301}!", 1, ""),
        ("e\u{301}!", 2, "e\u{301}"),
        ("a🇵🇱b", 2, "a")
    ])
    func `Prefix respects scalar limit without splitting characters`(text: String, limit: Int, expected: String) {
        // Arrange.
        let originalScalars = Array(text.unicodeScalars)

        // Act.
        let prefix = text.prefixWithUnicodeScalarLimit(limit)

        // Assert.
        #expect(prefix == expected)
        #expect(prefix.unicodeScalars.count <= max(0, limit))
        #expect(Array(prefix.unicodeScalars) == Array(originalScalars.prefix(prefix.unicodeScalars.count)))
    }
}
