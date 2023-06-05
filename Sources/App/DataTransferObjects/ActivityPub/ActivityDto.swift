//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ActivityDto: Content {
    public let context: ComplexTypeDtos<String>
    public let type: ActivityTypeDto
    public let id: String
    public let actor: ComplexTypeDtos<BaseActorDto>
    public let to: ComplexTypeDtos<BaseActorDto>?
    public let object: ComplexTypeDtos<BaseObjectDto>
    public let summary: String?
    public let signature: SignatureDto?
    
    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case type
        case id
        case actor
        case to
        case object
        case summary
        case signature
    }
}
