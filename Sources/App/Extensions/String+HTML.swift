//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import RegexBuilder

extension String {
    public func html() -> String {
        let tagsReplaced = self.replaceTag()
        let usernameReplaced = tagsReplaced.replaceUsername()
        return usernameReplaced.replaceUrl()
    }
    
    private func replaceTag() -> String {
        let hashtagPattern = #/(?<tag>#+[a-zA-Z0-9(_)]{1,})/#
        return self.replacing(hashtagPattern) { match in
            "<a href=\"/tags/\(match.tag.replacingOccurrences(of: "#", with: ""))\" class=\"hashtag\" rel=\"tag\">\(match.tag)</a>"
        }
    }
    
    private func replaceUsername() -> String {
        let usernamePattern = #/(?<username>@+[a-zA-Z0-9(_)]{1,})/#
        return self.replacing(usernamePattern) { match in
            "<a href=\"/\(match.username)\" class=\"username\">\(match.username)</a>"
        }
    }
    
    private func replaceUrl() -> String {
        let urlPattern = #/(?<address>https?:\/\/\S*)/#
        return self.replacing(urlPattern) { match in
            "<a href=\"\(match.address)\" rel=\"me nofollow noopener noreferrer\" class=\"url\" target=\"_blank\">\(match.address)</a>"
        }
    }
}
