//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public final class FollowDto: CommonObjectDto {
    public let actor: ComplexType<ActorDto>?
    public let object: ComplexType<ObjectDto>?
    
    init(actor: ComplexType<ActorDto>?, object: ComplexType<ObjectDto>?) {
        self.actor = actor
        self.object = object
    }
    
    enum CodingKeys: String, CodingKey {
        case actor
        case object
    }
}

extension FollowDto: Codable { }
