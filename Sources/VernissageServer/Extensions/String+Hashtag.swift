//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public extension String {
    func getHashtags() -> [String] {
        let hashtagPattern = #/(?<tag>#+[a-zA-Z0-9(_)]{1,})/#
        let matches = self.matches(of: hashtagPattern)
        
        let tags = matches.map { match in
            String(match.tag.trimmingPrefix("#"))
        }
        
        var uniqueTags: [String: String] = [:]
        tags.forEach { tag in
            let uppercasedTrimmedTag = tag.uppercased().trimmingCharacters(in: [" "])
            if uppercasedTrimmedTag.isEmpty == false && uniqueTags.keys.contains(uppercasedTrimmedTag) == false {
                uniqueTags[uppercasedTrimmedTag] = tag
            }
        }
        
        return uniqueTags.map { (_, value) in
            value
        }
    }
}
