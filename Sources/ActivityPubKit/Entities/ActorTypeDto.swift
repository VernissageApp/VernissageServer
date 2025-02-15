//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public enum ActorTypeDto: String {
    case application = "Application"
    case group = "Group"
    case organization = "Organization"
    case person = "Person"
    case service = "Service"
}

extension ActorTypeDto: Codable { }
extension ActorTypeDto: Sendable { }
