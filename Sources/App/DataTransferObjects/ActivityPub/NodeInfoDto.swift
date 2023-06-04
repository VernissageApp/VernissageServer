//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct NodeInfoDto {
    public let version: String
    public let openRegistrations: Bool
    public let software: NodeInfoSoftwareDto
    public let protocols: [String]
    public let services: NodeInfoServicesDto
    public let usage: NodeInfoUsageDto
    public let metadata: NodeInfoMetadataDto
}

extension NodeInfoDto: Content { }
