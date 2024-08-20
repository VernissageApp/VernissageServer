//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public struct LikeDto: CommonObjectDto {
    public let id: String
    public let type = "Like"
    public let actor: ComplexType<ActorDto>?
    public let to: ComplexType<ActorDto>?
    public let cc: ComplexType<ActorDto>?
    public let object: ComplexType<ObjectDto>?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case actor
        case to
        case cc
        case object
    }
    
    public init(
        id: String,
        actor: ComplexType<ActorDto>?,
        to: ComplexType<ActorDto>?,
        cc: ComplexType<ActorDto>?,
        object: ComplexType<ObjectDto>?
    ) {
        self.id = id
        self.actor = actor
        self.to = to
        self.cc = cc
        self.object = object
    }
}

extension LikeDto: Codable { }
