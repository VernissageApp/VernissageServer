//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@_documentation(visibility: private)
public enum CacheControl: Sendable {
    case `public`(maxAge: Int = 3600)
    case `private`(maxAge: Int = 3600)
    case noStore
}
