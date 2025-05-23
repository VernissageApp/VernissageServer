//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public struct NoteDto: CommonObjectDto {
    public let context: ComplexType<ContextDto>?
    public let id: String
    public let type = "Note"
    public let summary: String?
    public let inReplyTo: String?
    public let published: String?
    public let url: String
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
        case inReplyTo
        case published
        case url
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
        summary: String?,
        inReplyTo: String?,
        published: String?,
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
        self.summary = summary
        self.inReplyTo = inReplyTo
        self.published = published
        self.url = url
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

extension NoteDto: Codable { }


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
