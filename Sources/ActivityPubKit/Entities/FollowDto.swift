//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public final class FollowDto: CommonObjectDto {
    public let actor: ComplexType<BaseActorDto>?
    public let object: ComplexType<BaseObjectDto>?
    
    init(actor: ComplexType<BaseActorDto>?, object: ComplexType<BaseObjectDto>?) {
        self.actor = actor
        self.object = object
    }
    
    enum CodingKeys: String, CodingKey {
        case actor
        case object
    }
}

extension FollowDto: Codable { }
