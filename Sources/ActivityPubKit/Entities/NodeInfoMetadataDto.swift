//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct NodeInfoMetadataDto {
    public let nodeName: String
    public let nodeDescription: String
    
    public init(nodeName: String, nodeDescription: String) {
        self.nodeName = nodeName
        self.nodeDescription = nodeDescription
    }
}

extension NodeInfoMetadataDto: Codable { }
extension NodeInfoMetadataDto: Sendable { }
