//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct PersonEndpointsDto {
    public let sharedInbox: String
    
    public init(sharedInbox: String) {
        self.sharedInbox = sharedInbox
    }
}

extension PersonEndpointsDto: Codable { }
