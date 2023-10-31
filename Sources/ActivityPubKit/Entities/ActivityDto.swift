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
    public let actor: ComplexType<BaseActorDto>
    public let to: ComplexType<BaseActorDto>?
    public let cc: ComplexType<BaseActorDto>?
    public let object: ComplexType<BaseObjectDto>
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
                actor: ComplexType<BaseActorDto>,
                to: ComplexType<BaseActorDto>? = nil,
                cc: ComplexType<BaseActorDto>? = nil,
                object: ComplexType<BaseObjectDto>,
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

extension ComplexType<BaseActorDto> {
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

extension ComplexType<BaseObjectDto> {
    public func objects() -> [BaseObjectDto] {
        var objects: [BaseObjectDto] = []
        
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

extension ActivityDto {
    // TODO: Remove hardcoded id.
    public static func follow(sourceActorId: String, targetActorId: String) -> ActivityDto {
        return ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                           type: .follow,
                           id: "\(sourceActorId)#follow/590451308086793127",
                           actor: .single(BaseActorDto(id: sourceActorId)),
                           to: nil,
                           object: .single(BaseObjectDto(id: targetActorId)),
                           summary: nil,
                           signature: nil)
    }
    
    // TODO: Remove hardcoded id.
    public static func unfollow(sourceActorId: String, targetActorId: String) -> ActivityDto {
        return ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                           type: .undo,
                           id: "\(sourceActorId)#undo/590451308086793127",
                           actor: .single(BaseActorDto(id: sourceActorId)),
                           to: nil,
                           object: .single(BaseObjectDto(id: "\(sourceActorId)#follow/590451308086793127",
                                                         type: .follow,
                                                         object: FollowDto(actor: .single(BaseActorDto(id: sourceActorId)),
                                                                           object: .single(BaseObjectDto(id: targetActorId))))),
                           summary: nil,
                           signature: nil)
    }
}
