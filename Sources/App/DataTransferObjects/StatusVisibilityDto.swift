//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum StatusVisibilityDto: String {
    case `public`
    case unlisted
    case followers
}

extension StatusVisibilityDto {
    public func translate() -> StatusVisibility {
        switch self {
        case .public:
            return StatusVisibility.public
        case .unlisted:
            return StatusVisibility.unlisted
        case .followers:
            return StatusVisibility.followers
        }
    }
    
    public static func from(_ statusVisibility: StatusVisibility) -> StatusVisibilityDto {
        switch statusVisibility {
        case .public:
            return StatusVisibilityDto.public
        case .unlisted:
            return StatusVisibilityDto.unlisted
        case .followers:
            return StatusVisibilityDto.followers
        }
    }
}

extension StatusVisibilityDto: Content { }
