//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum StatusVisibilityDto: String {
    case `public`
    case followers
    case mentioned
}

extension StatusVisibilityDto {
    public func translate() -> StatusVisibility {
        switch self {
        case .public:
            return StatusVisibility.public
        case .followers:
            return StatusVisibility.followers
        case .mentioned:
            return StatusVisibility.mentioned
        }
    }
    
    public static func from(_ statusVisibility: StatusVisibility) -> StatusVisibilityDto {
        switch statusVisibility {
        case .public:
            return StatusVisibilityDto.public
        case .followers:
            return StatusVisibilityDto.followers
        case .mentioned:
            return StatusVisibilityDto.mentioned
        }
    }
}

extension StatusVisibilityDto: Content { }
