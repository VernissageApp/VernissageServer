//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public final class BaseObjectDto {
    public let id: String
    public let type: ObjectTypeDto
    public let name: String?
    public let actor: ComplexType<ItemKind<BaseActorDto>>?
    public let to: ComplexType<BaseActorDto>?
    public let object: ComplexType<ItemKind<BaseObjectDto>>?
    public let content: String?
    public let url: String?
    public let sensitive: Bool?
    public let contentWarning: String?
    public let attributedTo: String?
    public let attachment: [AttachmentDto]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case actor
        case to
        case object
        case content
        case url
        case sensitive
        case contentWarning
        case attributedTo
        case attachment
    }
    
    public init(id: String,
                type: ObjectTypeDto,
                name: String? = nil,
                actor: ComplexType<ItemKind<BaseActorDto>>? = nil,
                to: ComplexType<BaseActorDto>? = nil,
                object: ComplexType<ItemKind<BaseObjectDto>>? = nil,
                content: String? = nil,
                url: String? = nil,
                sensitive: Bool? = nil,
                contentWarning: String? = nil,
                attributedTo: String? = nil,
                attachment: [AttachmentDto]? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.actor = actor
        self.to = to
        self.object = object
        self.content = content
        self.url = url
        self.sensitive = sensitive
        self.contentWarning = contentWarning
        self.attributedTo = attributedTo
        self.attachment = attachment
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            self.id = try container.decode(String.self)
            self.type = .profile
            self.name = nil
            self.actor = nil
            self.to = nil
            self.object = nil
            self.content = nil
            self.url = nil
            self.sensitive = nil
            self.contentWarning = nil
            self.attributedTo = nil
            self.attachment = nil
        } catch DecodingError.typeMismatch {
            let objectData = try container.decode(BaseObjectDataDto.self)
            self.id = objectData.id
            self.type = objectData.type
            self.name = objectData.name
            self.actor = objectData.actor
            self.to = objectData.to
            self.object = objectData.object
            self.content = objectData.content
            self.url = objectData.url
            self.sensitive = objectData.sensitive
            self.contentWarning = objectData.contentWarning
            self.attributedTo = objectData.attributedTo
            self.attachment = objectData.attachment
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.actor, forKey: .actor)
        try container.encode(self.to, forKey: .to)
        try container.encode(self.object, forKey: .object)
        try container.encode(self.content, forKey: .content)
        try container.encode(self.url, forKey: .url)
        try container.encode(self.sensitive, forKey: .sensitive)
        try container.encode(self.contentWarning, forKey: .contentWarning)
        try container.encode(self.attributedTo, forKey: .attributedTo)
        try container.encode(self.attachment, forKey: .attachment)
    }
}

extension BaseObjectDto: Equatable {
    public static func == (lhs: BaseObjectDto, rhs: BaseObjectDto) -> Bool {
        return lhs.id == rhs.id && lhs.type == rhs.type
    }
}

extension BaseObjectDto: Codable { }

final fileprivate class BaseObjectDataDto {
    public let id: String
    public let type: ObjectTypeDto
    public let name: String?
    public let actor: ComplexType<ItemKind<BaseActorDto>>?
    public let to: ComplexType<BaseActorDto>?
    public let object: ComplexType<ItemKind<BaseObjectDto>>?
    public let content: String?
    public let url: String?
    public let sensitive: Bool?
    public let contentWarning: String?
    public let attributedTo: String?
    public let attachment: [AttachmentDto]?
}

extension BaseObjectDataDto: Codable { }
