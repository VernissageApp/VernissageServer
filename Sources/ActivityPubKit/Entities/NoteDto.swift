//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public struct NoteDto: CommonObjectDto {
    public let context: ComplexType<ContextDto>?
    public let id: String
    public let type: String
    public let summary: String?
    public let inReplyToRaw: ComplexType<ReplyToDto>?
    public let published: String?
    public let updated: String?
    public let urlRaw: ComplexType<UrlDto>?
    public let attributedTo: String
    public let to: ComplexType<ActorDto>?
    public let cc: ComplexType<ActorDto>?
    public let sensitive: Bool?
    public let atomUri: String?
    public let inReplyToAtomUri: String?
    public let conversation: String?
    public let content: String?
    public let attachment: [MediaAttachmentDto]?
    public let tag: ComplexType<NoteTagDto>?
    
    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case type
        case summary
        case inReplyToRaw = "inReplyTo"
        case published
        case updated
        case urlRaw = "url"
        case attributedTo
        case to
        case cc
        case sensitive
        case atomUri
        case inReplyToAtomUri
        case conversation
        case content
        case attachment
        case tag
    }
    
    public init(
        id: String,
        type: String = "Note",
        summary: String?,
        inReplyTo: String?,
        published: String?,
        updated: String?,
        url: String,
        attributedTo: String,
        to: ComplexType<ActorDto>?,
        cc: ComplexType<ActorDto>?,
        sensitive: Bool?,
        atomUri: String?,
        inReplyToAtomUri: String?,
        conversation: String?,
        content: String?,
        attachment: [MediaAttachmentDto]?,
        tag: ComplexType<NoteTagDto>?
    ) {
        self.context = ContextDto.createNoteContext()
        self.id = id
        self.type = type
        self.summary = summary
        self.published = published
        self.updated = updated
        self.urlRaw = .single(UrlDto(href: url))
        self.attributedTo = attributedTo
        self.to = to
        self.cc = cc
        self.atomUri = atomUri
        self.inReplyToAtomUri = inReplyToAtomUri
        self.conversation = conversation
        self.content = content
        self.attachment = attachment
        self.tag = tag
        self.sensitive = sensitive
        
        if let inReplyTo {
            self.inReplyToRaw = .single(ReplyToDto(id: inReplyTo))
        } else {
            self.inReplyToRaw = nil
        }
    }
}

extension NoteDto {
    /// Some instances are returning more then one `url` and some even more complex type.
    /// However in the database we can store only one url to the status.
    public var url : String {
        return self.urlRaw?.firstUrl() ?? ""
    }
    
    /// Some instances are returning two properties: `id` and `url` instead only `id` as string to parent status.
    public var inReplyTo: String? {
        return self.inReplyToRaw?.firstReplyTo()
    }
}

public extension NoteDto {
    func isComment() -> Bool {
        guard let parentStatusId = self.inReplyTo else {
            return false
        }
        
        return parentStatusId.isEmpty == false
    }
}

extension ComplexType<UrlDto> {
    public func firstUrl() -> String? {
        switch self {
        case .single(let urlDto):
            return urlDto.href
        case .multiple(let urlDtos):
            return urlDtos.first?.href
        }
    }
}

extension ComplexType<ReplyToDto> {
    public func firstReplyTo() -> String? {
        switch self {
        case .single(let replyToDto):
            return replyToDto.id
        case .multiple(let replyToDtos):
            return replyToDtos.first?.id
        }
    }
}

extension NoteDto: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.context = try container.decodeIfPresent(ComplexType<ContextDto>.self, forKey: .context)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary)
        self.inReplyToRaw = try container.decodeIfPresent(ComplexType<ReplyToDto>.self, forKey: .inReplyToRaw)
        self.published = try container.decodeIfPresent(String.self, forKey: .published)
        self.updated = try container.decodeIfPresent(String.self, forKey: .updated)
        self.urlRaw = try container.decodeIfPresent(ComplexType<UrlDto>.self, forKey: .urlRaw)

        let attributedTo = try container.decode(ComplexType<ActorDto>.self, forKey: .attributedTo)
        self.attributedTo = attributedTo.actorIds().first ?? ""

        self.to = try container.decodeIfPresent(ComplexType<ActorDto>.self, forKey: .to)
        self.cc = try container.decodeIfPresent(ComplexType<ActorDto>.self, forKey: .cc)
        self.sensitive = try container.decodeIfPresent(Bool.self, forKey: .sensitive)
        self.atomUri = try container.decodeIfPresent(String.self, forKey: .atomUri)
        self.inReplyToAtomUri = try container.decodeIfPresent(String.self, forKey: .inReplyToAtomUri)
        self.conversation = try container.decodeIfPresent(String.self, forKey: .conversation)
        self.content = try container.decodeIfPresent(String.self, forKey: .content)
        self.attachment = try container.decodeIfPresent([MediaAttachmentDto].self, forKey: .attachment)
        self.tag = try container.decodeIfPresent(ComplexType<NoteTagDto>.self, forKey: .tag)
    }
}


extension ComplexType<NoteTagDto> {
    public func tags() -> [NoteTagDto] {
        var hashtags: [NoteTagDto] = []
        
        switch self {
        case .single(let hashtagDto):
            hashtags.append(hashtagDto)
        case .multiple(let hashtagDtos):
            for hashtagDto in hashtagDtos {
                hashtags.append(hashtagDto)
            }
        }
        
        return hashtags
    }
    
    public func hashtags() -> [NoteTagDto] {
        tags().filter { $0.type == "Hashtag" && $0.name.isEmpty == false }
    }
    
    public func mentions() -> [NoteTagDto] {
        tags().filter { $0.type == "Mention" && $0.name.isEmpty == false }
    }
    
    public func categories() -> [NoteTagDto] {
        tags().filter { $0.type == "Category" && $0.name.isEmpty == false }
    }
    
    public func emojis() -> [NoteTagDto] {
        tags().filter { $0.type == "Emoji" && $0.name.isEmpty == false && $0.icon != nil && $0.icon?.url.isEmpty == false }
    }
}
