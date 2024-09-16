//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import RegexBuilder
import Ink

extension String {
    public func html(baseAddress: String) -> String {
        var lines = self.split(separator: "\n").map({ String($0) })
        
        for (index, line) in lines.enumerated() {
            lines[index] = line
                .convertTagsIntoMarkdown(baseAddress: baseAddress)
                .convertUsernamesIntoMarkdown(baseAddress: baseAddress)
                .convertUrlsIntoHtml()
        }
        
        let converted = lines.joined(separator: "<br />")
        return converted.convertMarkdownToHtml()
    }
    
    private func convertTagsIntoMarkdown(baseAddress: String) -> String {
        let hashtagPattern = #/(?<prefix>^|[ \/\\+\-=!<>,\.:;*"'{}]{1})(?<tag>#[a-zA-Z0-9_]{1,})/#
        return self.replacing(hashtagPattern) { match in
            "\(match.prefix)[\(match.tag)](\(baseAddress)/tags/\(match.tag.replacingOccurrences(of: "#", with: "")))"
        }
    }
    
    private func convertUsernamesIntoMarkdown(baseAddress: String) -> String {
        let usernamePattern = #/(?<prefix>^|[ +\-=!<>,\.:;*"'{}]{1})(?<username>@[a-zA-Z0-9(_)]{1,})(?<domain>[@a-zA-Z0-9_\-\.]{0,})/#
        return self.replacing(usernamePattern) { match in
            let domain = match.domain.isEmpty ? baseAddress : "https://\(String(match.domain).deletingPrefix("@"))"
            return "\(match.prefix)[\(match.username)\(match.domain)](\(domain)/\(match.username))"
        }
    }
    
    private func convertUrlsIntoHtml() -> String {
        let urlPattern = #/(?<prefix>^|[ +\-=!<>,\.:;*"'{}]{1})(?<address>https?:\/\/\S*)/#
        return self.replacing(urlPattern) { match in
            let withoutSchema = match.address.replacingOccurrences(of: "https://", with: "")
            return "\(match.prefix)<a href=\"\(match.address)\" rel=\"me nofollow noopener noreferrer\" class=\"url\" target=\"_blank\"><span class=\"invisible\">https://</span>\(withoutSchema)</a>"
        }
    }
    
    private func convertMarkdownToHtml() -> String {
        let parser = MarkdownParser()
        return parser.html(from: self)
    }
}
