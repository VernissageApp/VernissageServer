//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public struct ActivityDto {
    public let context: ComplexType<ContextDto>
    public let type: ActivityTypeDto
    public let id: String
    public let actor: ComplexType<ActorDto>
    public let to: ComplexType<ActorDto>?
    public let cc: ComplexType<ActorDto>?
    public let object: ComplexType<ObjectDto>
    public let summary: String?
    public let signature: SignatureDto?
    
    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case type
        case id
        case actor
        case to
        case cc
        case object
        case summary
        case signature
    }
    
    public init(context: ComplexType<ContextDto>,
                type: ActivityTypeDto,
                id: String,
                actor: ComplexType<ActorDto>,
                to: ComplexType<ActorDto>? = nil,
                cc: ComplexType<ActorDto>? = nil,
                object: ComplexType<ObjectDto>,
                summary: String?,
                signature: SignatureDto?
    ) {
        self.context = context
        self.type = type
        self.id = id
        self.actor = actor
        self.to = to
        self.cc = cc
        self.object = object
        self.summary = summary
        self.signature = signature
    }
}

extension ActivityDto: Codable { }

extension ComplexType<ActorDto> {
    public func actorIds() -> [String] {
        var actors: [String] = []
        
        switch self {
        case .single(let actorDto):
            actors.append(actorDto.id)
        case .multiple(let actorDtos):
            for actorDto in actorDtos {
                actors.append(actorDto.id)
            }
        }
        
        return actors
    }
}

extension ComplexType<ObjectDto> {
    public func objects() -> [ObjectDto] {
        var objects: [ObjectDto] = []
        
        switch self {
        case .single(let objectDto):
            objects.append(objectDto)
        case .multiple(let objectDtos):
            for objectDto in objectDtos {
                objects.append(objectDto)
            }
        }
        
        return objects
    }
}
