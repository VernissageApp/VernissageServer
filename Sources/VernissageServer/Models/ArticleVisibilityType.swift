//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Article visibility type.
enum ArticleVisibilityType: Int, Codable {
    case signOutHome = 1
    case signInHome = 2
    case signInNews = 3
    case signOutNews = 4
}
