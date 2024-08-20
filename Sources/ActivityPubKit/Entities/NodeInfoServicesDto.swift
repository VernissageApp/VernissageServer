//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct NodeInfoServicesDto {
    public let outbound: [String]
    public let inbound: [String]
    
    public init(outbound: [String], inbound: [String]) {
        self.outbound = outbound
        self.inbound = inbound
    }
}

extension NodeInfoServicesDto: Codable { }
