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
    public let actor: ComplexType<ItemKind<BaseActorDto>>
    public let to: ComplexType<ItemKind<BaseActorDto>>?
    public let cc: ComplexType<ItemKind<BaseActorDto>>?
    public let object: ComplexType<ItemKind<BaseObjectDto>>
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
                actor: ComplexType<ItemKind<BaseActorDto>>,
                to: ComplexType<ItemKind<BaseActorDto>>? = nil,
                cc: ComplexType<ItemKind<BaseActorDto>>? = nil,
                object: ComplexType<ItemKind<BaseObjectDto>>,
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

extension ComplexType<ItemKind<BaseActorDto>> {
    public func actorIds() -> [String] {
        var actors: [String] = []
        
        switch self {
        case .single(let itemKind):
            switch itemKind {
            case .string(let actorId):
                actors.append(actorId)
            case .object(let baseActorDto):
                actors.append(baseActorDto.id)
            }
        case .multiple(let itemKinds):
            for itemKind in itemKinds {
                switch itemKind {
                case .string(let actorId):
                    actors.append(actorId)
                case .object(let baseActorDto):
                    actors.append(baseActorDto.id)
                }
            }
        }
        
        return actors
    }
}

extension ComplexType<ItemKind<BaseObjectDto>> {    
    public func objects() -> [BaseObjectDto] {
        var objects: [BaseObjectDto] = []
        
        switch self {
        case .single(let itemKind):
            switch itemKind {
            case .string(let objectId):
                objects.append(BaseObjectDto(id: objectId, type: .profile))
            case .object(let baseObjectDto):
                objects.append(baseObjectDto)
            }
        case .multiple(let itemKinds):
            for itemKind in itemKinds {
                switch itemKind {
                case .string(let objectId):
                    objects.append(BaseObjectDto(id: objectId, type: .profile))
                case .object(let baseObjectDto):
                    objects.append(baseObjectDto)
                }
            }
        }
        
        return objects
    }
}

extension ActivityDto {
    public static func follow(sourceActorId: String, targetActorId: String) -> ActivityDto {
        return ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                           type: .follow,
                           id: "\(sourceActorId)#follow/590451308086793127",
                           actor: .single(.string(sourceActorId)),
                           to: nil,
                           object: .single(.string(targetActorId)),
                           summary: nil,
                           signature: nil)
    }
    
    public static func unfollow(sourceActorId: String, targetActorId: String) -> ActivityDto {
        return ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                           type: .undo,
                           id: "\(sourceActorId)#undo/590451308086793127",
                           actor: .single(.string(sourceActorId)),
                           to: nil,
                           object: .single(.object(.init(id: "\(sourceActorId)#follow/590451308086793127",
                                                         type: .follow,
                                                         actor: .single(.string(sourceActorId)),
                                                         object: .single(.string(targetActorId))))),
                           summary: nil,
                           signature: nil)
    }
}
