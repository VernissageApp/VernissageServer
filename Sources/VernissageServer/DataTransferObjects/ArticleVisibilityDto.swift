//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum ArticleVisibilityDto: String {
    case signOutHome
    case signInHome
    case signInNews
    case signOutNews
}

extension ArticleVisibilityDto {
    public func translate() -> ArticleVisibilityType {
        switch self {
        case .signOutHome:
            return ArticleVisibilityType.signOutHome
        case .signInHome:
            return ArticleVisibilityType.signInHome
        case .signInNews:
            return ArticleVisibilityType.signInNews
        case .signOutNews:
            return ArticleVisibilityType.signOutNews
        }
    }
    
    public static func from(_ statusVisibility: ArticleVisibilityType) -> ArticleVisibilityDto {
        switch statusVisibility {
        case .signOutHome:
            return ArticleVisibilityDto.signOutHome
        case .signInHome:
            return ArticleVisibilityDto.signInHome
        case .signInNews:
            return ArticleVisibilityDto.signInNews
        case .signOutNews:
            return ArticleVisibilityDto.signOutNews
        }
    }
}

extension ArticleVisibilityDto: Content { }
