//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public enum UrlTypeDto: String {
    case link = "Link"
}

extension UrlTypeDto: Codable { }
extension UrlTypeDto: Sendable { }
