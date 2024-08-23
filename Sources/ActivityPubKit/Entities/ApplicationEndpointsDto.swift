//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct ApplicationEndpointsDto {
    public let sharedInbox: String
    
    public init(sharedInbox: String) {
        self.sharedInbox = sharedInbox
    }
}

extension ApplicationEndpointsDto: Codable { }
