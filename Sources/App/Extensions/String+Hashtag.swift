//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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
        
        return tags.filter { tag in
            tag.isEmpty == false
        }
    }
}
