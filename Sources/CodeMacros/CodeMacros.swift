//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct CodeMacros: CompilerPlugin {
    public let providingMacros: [any Macro.Type] = [
        CacheableMacro.self
    ]
}
