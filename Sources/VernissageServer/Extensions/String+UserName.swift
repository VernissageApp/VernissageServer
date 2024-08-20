//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public extension String {
    func getUserNames() -> [String] {
        let hashtagPattern = #/(?<username>@+[a-zA-Z0-9(_)@.]{1,})/#
        let matches = self.matches(of: hashtagPattern)
        
        let userNames = matches.map { match in
            String(match.username.trimmingCharacters(in: CharacterSet(charactersIn: "@.")))
        }
        
        return userNames.filter { userName in
            userName.isEmpty == false
        }
    }
}
