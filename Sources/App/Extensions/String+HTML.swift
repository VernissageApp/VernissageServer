//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import RegexBuilder
import Ink

extension String {
    public func html() -> String {
        var lines = self.split(separator: "\n").map({ String($0) })
        
        for (index, line) in lines.enumerated() {
            lines[index] = line
                .convertTagsIntoMarkdown()
                .convertUsernamesIntoMarkdown()
                .convertUrlsIntoHtml()
        }
        
        let converted = lines.joined(separator: "\n")
        return converted.convertMarkdownToHtml()
    }
    
    private func convertTagsIntoMarkdown() -> String {
        let hashtagPattern = #/(?<prefix>^|[ ]{1})(?<tag>#+[a-zA-Z0-9(_)]{1,})/#
        return self.replacing(hashtagPattern) { match in
            "\(match.prefix)[\(match.tag)](/tags/\(match.tag.replacingOccurrences(of: "#", with: "")))"
        }
    }
    
    private func convertUsernamesIntoMarkdown() -> String {
        let usernamePattern = #/(?<prefix>^|[ ]{1})(?<username>@+[a-zA-Z0-9(_)]{1,})/#
        return self.replacing(usernamePattern) { match in
            "\(match.prefix)[\(match.username)](/\(match.username))"
        }
    }
    
    private func convertUrlsIntoHtml() -> String {
        let urlPattern = #/(?<prefix>^|[ ]{1})(?<address>https?:\/\/\S*)/#
        return self.replacing(urlPattern) { match in
            "\(match.prefix)<a href=\"\(match.address)\" rel=\"me nofollow noopener noreferrer\" class=\"url\" target=\"_blank\">\(match.address)</a>"
        }
    }
    
    private func convertMarkdownToHtml() -> String {
        let parser = MarkdownParser()
        return parser.html(from: self)
    }
}
