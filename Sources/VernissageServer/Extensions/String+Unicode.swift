//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

extension String {
    /// Returns a prefix limited by Unicode scalars, preserving complete characters such as combined emoji.
    ///
    /// PostgreSQL counts Unicode scalars for UTF-8 `varchar` limits, while Swift counts grapheme clusters.
    /// - Parameter limit: Maximum number of Unicode scalars; nonpositive values return an empty string.
    /// - Returns: The longest prefix that fits the limit without splitting a character.
    func prefixWithUnicodeScalarLimit(_ limit: Int) -> String {
        guard limit > 0 else {
            return ""
        }

        var result = ""
        var scalarCount = 0

        for character in self {
            let characterScalarCount = character.unicodeScalars.count

            guard characterScalarCount <= limit - scalarCount else {
                break
            }

            result.append(character)
            scalarCount += characterScalarCount
        }

        return result
    }
}
