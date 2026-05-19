//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Source code location.
public struct SourceLocation: Sendable {

    /// File in which this location exists.
    public var file: String

    /// Function in which this location exists.
    public var function: String

    /// Line number this location belongs to.
    public var line: UInt

    /// Number of characters into the line this location starts at.
    public var column: UInt

    /// Optional start/end range of the source.
    public var range: Range<UInt>?

    /// Creates a new `SourceLocation`.
    public init(file: String, function: String, line: UInt, column: UInt, range: Range<UInt>?) {
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.range = range
    }
}
