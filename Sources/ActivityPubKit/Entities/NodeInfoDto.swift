//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct NodeInfoDto {
    public let version: String
    public let openRegistrations: Bool
    public let software: NodeInfoSoftwareDto
    public let protocols: [String]
    public let services: NodeInfoServicesDto
    public let usage: NodeInfoUsageDto
    public let metadata: NodeInfoMetadataDto
    
    public init(version: String,
                openRegistrations: Bool,
                software: NodeInfoSoftwareDto,
                protocols: [String],
                services: NodeInfoServicesDto,
                usage: NodeInfoUsageDto,
                metadata: NodeInfoMetadataDto
    ) {
        self.version = version
        self.openRegistrations = openRegistrations
        self.software = software
        self.protocols = protocols
        self.services = services
        self.usage = usage
        self.metadata = metadata
    }
}

extension NodeInfoDto: Codable { }
