//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public struct NoteDto: CommonObjectDto {
    public let context = ["https://www.w3.org/ns/activitystreams"]
    public let id: String
    public let type = "Note"
    public let summary: String?
    public let inReplyTo: String?
    public let published: Date?
    public let url: String
    public let attributedTo: String
    public let to: ComplexType<ActorDto>?
    public let cc: ComplexType<ActorDto>?
    public let sensitive = false
    public let contentWarning: String?
    public let atomUri: String?
    public let inReplyToAtomUri: String?
    public let conversation: String?
    public let content: String?
    public let attachment: [AttachmentDto]?
    public let tag: [NoteHashtagDto]?
    
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
        case contentWarning
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
        published: Date?,
        url: String,
        attributedTo: String,
        to: ComplexType<ActorDto>?,
        cc: ComplexType<ActorDto>?,
        contentWarning: String?,
        atomUri: String?,
        inReplyToAtomUri: String?,
        conversation: String?,
        content: String?,
        attachment: [AttachmentDto]?,
        tag: [NoteHashtagDto]?
    ) {
        self.id = id
        self.summary = summary
        self.inReplyTo = inReplyTo
        self.published = published
        self.url = url
        self.attributedTo = attributedTo
        self.to = to
        self.cc = cc
        self.contentWarning = contentWarning
        self.atomUri = atomUri
        self.inReplyToAtomUri = inReplyToAtomUri
        self.conversation = conversation
        self.content = content
        self.attachment = attachment
        self.tag = tag
    }
}

extension NoteDto: Codable { }
