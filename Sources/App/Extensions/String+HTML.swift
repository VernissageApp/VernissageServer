//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import RegexBuilder

extension String {
    public func html() -> String {
        let tagsReplaced = self.replaceTag()
        return tagsReplaced.replaceUrl()
    }
    
    private func replaceTag() -> String {
        let hashtagPattern = #/(?<tag>#+[a-zA-Z0-9(_)]{1,})/#
        return self.replacing(hashtagPattern) { match in
            "<a href=\"\(match.tag)\" rel=\"me nofollow noopener noreferrer\" target=\"_blank\">\(match.tag)</a>"
        }
    }
    
    private func replaceUrl() -> String {
        let urlPattern = #/(?<address>https?:\/\/\S*)/#
        return self.replacing(urlPattern) { match in
            "<a href=\"\(match.address)\" rel=\"me nofollow noopener noreferrer\" target=\"_blank\">\(match.address)</a>"
        }
    }
}
