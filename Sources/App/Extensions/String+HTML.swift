//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

extension String {
    public func html() -> String {
        return "<a href=\"\(self)\" rel=\"me nofollow noopener noreferrer\" target=\"_blank\">\(self)</a>"
    }
}
