//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// @attached(body)
@attached(peer, names: suffixed(_peer))
public macro Cacheable(_ cacheKey: String? = nil) = #externalMacro(module: "CodeMacros", type: "CacheableMacro")
