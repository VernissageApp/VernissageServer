//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import RegexBuilder
import Ink

extension String {
    public func html(baseAddress: String, wrapInParagraph: Bool = false, userNameMaps: [String: String]? = nil) -> String {
        var lines = self.split(separator: "\n", omittingEmptySubsequences: false).map({ String($0) })
        
        for (index, line) in lines.enumerated() {
            lines[index] = line
                .convertUrlsIntoHtml()
                .convertUsernamesIntoHtml(baseAddress: baseAddress, userNameMaps: userNameMaps)
                .convertTagsIntoHtml(baseAddress: baseAddress)
        }
        
        let converted = lines.joined(separator: "<br />")

        if wrapInParagraph {
            return "<p>\(converted)</p>"
        }

        return converted
    }
    
    public func markdownHtml(baseAddress: String) -> String {
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
        let hashtagPattern = #/(?<prefix>^|[ \/\\+\-=!<>,\.:;*"'{}]{1})(?<tag>#[a-zA-Z\u00C0-\u024F\u1E00-\u1EFF\u0100-\u017F\u0180-\u024F0-9_]{1,})/#
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

    private func convertTagsIntoHtml(baseAddress: String) -> String {
        let hashtagPattern = #/(?<prefix>^|[ \/\\+\-=!<>,\.:;*"'{}]{1})(?<tag>#[a-zA-Z\u00C0-\u024F\u1E00-\u1EFF\u0100-\u017F\u0180-\u024F0-9_]{1,})/#
        return self.replacing(hashtagPattern) { match in
            // "\(match.prefix)[\(match.tag)](\(baseAddress)/tags/\(match.tag.replacingOccurrences(of: "#", with: "")))"
            "\(match.prefix)<a href=\"\(baseAddress)/tags/\(match.tag.replacingOccurrences(of: "#", with: ""))\" rel=\"tag\" class=\"mention hashtag\">\(match.tag)</a>"
        }
    }
    
    private func convertUsernamesIntoHtml(baseAddress: String, userNameMaps: [String: String]?) -> String {
        let usernamePattern = #/(?<prefix>^|[ +\-=!<>,\.:;*"'{}]{1})(?<username>@[\w](?:[\w\.+-]*[\w])?)(?<domain>@[\w](?:[\w\.+-]*[\w])?){0,}/#
        return self.replacing(usernamePattern) { match in
            let matchedDomain =  match.domain ?? ""
            let domain = matchedDomain.isEmpty ? baseAddress : "https://\(String(matchedDomain).deletingPrefix("@"))"
            
            let accountNormalized = "\(match.username)\(matchedDomain)".trimmingPrefix("@").uppercased()
            let href = userNameMaps?[accountNormalized] ?? "\(domain)/\(match.username)"

            return "\(match.prefix)<a href=\"\(href)\" class=\"username\" target=\"_blank\">\(match.username)\(matchedDomain)</a>"
        }
    }
    
    private func convertUrlsIntoHtml() -> String {
        let urlPattern = #/(?<prefix>^|[ +\-=!<>,\.:;*"'{}()\[\]]{1})(?<address>https?:\/\/[^\r\n\t\f\v(){}:;*"'<>{}()\[\] ]*)/#
        return self.replacing(urlPattern) { match in
            let withoutSchema = match.address.replacingOccurrences(of: "https://", with: "")
            return "\(match.prefix)<a href=\"\(match.address)\" rel=\"me nofollow noopener noreferrer\" class=\"url\" target=\"_blank\"><span class=\"invisible\">https://</span>\(withoutSchema)</a>"
        }
    }
    
    private func convertMarkdownToHtml() -> String {
        let parser = MarkdownParser()
        return parser.html(from: self)
    }
    
    private func isCorrectUrl(domain: String) -> Bool {
        if let url = URL(string: domain), url.host != nil {
            return true
        }
        
        return false
    }
}
