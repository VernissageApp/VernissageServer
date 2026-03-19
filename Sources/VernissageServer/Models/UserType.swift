//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import ActivityPubKit

/// Actor types are Object types that are capable of performing activities.
enum UserType: Int, Codable {
    /// Not recognized actor type.
    case unknown = 0

    /// Represents an individual person.
    case person = 1
    
    /// Describes a software application.
    case application = 2
    
    /// Represents a formal or informal collective of Actors.
    case group = 3
    
    /// Represents an organization.
    case organization = 4
    
    /// Represents a service of any kind.
    case service = 5
}

extension PersonDto {
    func getUserType() -> UserType {
        switch self.type.uppercased() {
        case "PERSON":
            return .person
        case "APPLICATION":
            return .application
        case "GROUP":
            return .group
        case "ORGANIZATION":
            return .organization
        case "SERVICE":
            return .service
        default:
            return .unknown
        }
    }
    
    func getUrl() throws -> String? {
        switch self.type.uppercased() {
        case "SERVICE":
            return self.url?.values().first
        default:
            let urls = self.url?.values()
            guard let urls, let personUrl = urls.first else {
                throw PersonError.missingUrl
            }
                    
            return personUrl
        }
    }
    
    func getRemoteUserName() throws -> String {
        switch self.type.uppercased() {
        case "SERVICE":
            return self.preferredUsername
        default:
            let urls = self.url?.values()
            guard let urls, let personUrl = urls.first else {
                throw PersonError.missingUrl
            }
                    
            if self.preferredUsername.hasSuffix("@\(personUrl.host)") {
                return self.preferredUsername
            } else {
                return "\(self.preferredUsername)@\(personUrl.host)"
            }
        }
    }
}
