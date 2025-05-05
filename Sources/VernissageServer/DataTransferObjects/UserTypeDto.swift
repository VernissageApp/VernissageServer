//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum UserTypeDto: String {
    /// Not recognized actor type.
    case unknown

    /// Represents an individual person.
    case person
    
    /// Describes a software application.
    case application
    
    /// Represents a formal or informal collective of Actors.
    case group
    
    /// Represents an organization.
    case organization
    
    /// Represents a service of any kind.
    case service
}

extension UserTypeDto {
    public func translate() -> UserType {
        switch self {
        case .unknown:
            return UserType.unknown
        case .person:
            return UserType.person
        case .application:
            return UserType.application
        case .group:
            return UserType.group
        case .organization:
            return UserType.organization
        case .service:
            return UserType.service
        }
    }
    
    public static func from(_ userType: UserType) -> UserTypeDto {
        switch userType {
        case .unknown:
            return UserTypeDto.unknown
        case .person:
            return UserTypeDto.person
        case .application:
            return UserTypeDto.application
        case .group:
            return UserTypeDto.group
        case .organization:
            return UserTypeDto.organization
        case .service:
            return UserTypeDto.service
        }
    }
}

extension UserTypeDto: Content { }
