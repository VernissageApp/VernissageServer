//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct NodeInfoMetadataDto {
    public let nodeName: String
    
    public init(nodeName: String) {
        self.nodeName = nodeName
    }
}

extension NodeInfoMetadataDto: Codable { }
