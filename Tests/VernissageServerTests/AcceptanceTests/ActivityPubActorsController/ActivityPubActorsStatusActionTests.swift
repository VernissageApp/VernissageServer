//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing

extension ControllersTests {
    
    @Suite("ActivityPubActor (GET /actors/:username/statuses/:id)", .serialized, .tags(.actors))
    struct ActivityPubActorsStatusActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Actor status should be returned for existing actor`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "trondfoter")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "AP note 1", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let noteDto = try await application.getResponse(
                to: "/actors/trondfoter/statuses/\(statuses.first!.requireID())",
                version: .none,
                decodeTo: NoteDto.self
            )
            
            // Assert.
            #expect(noteDto.id == "http://localhost:8080/actors/trondfoter/statuses/\(statuses.first?.stringId() ?? "")", "Property 'id' is not valid.")
            #expect(noteDto.attachment?.count == 1, "Property 'attachment' is not valid.")
            #expect(noteDto.attributedTo == "http://localhost:8080/actors/trondfoter", "Property 'attributedTo' is not valid.")
            #expect(noteDto.url == "http://localhost:8080/@trondfoter/\(statuses.first?.stringId() ?? "")", "Property 'url' is not valid.")
        }
        
        @Test
        func `Status without api prefix should be returned for unauthorized`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "goronfoter")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "AP note 1", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let noteDto = try await application.getResponse(
                to: "/statuses/\(statuses.first!.requireID())",
                version: .none,
                method: .GET,
                decodeTo: NoteDto.self
            )
            
            // Assert.
            #expect(noteDto.id == "http://localhost:8080/actors/goronfoter/statuses/\(statuses.first?.stringId() ?? "")", "Property 'id' is not valid.")
            #expect(noteDto.attachment?.count == 1, "Property 'attachment' is not valid.")
            #expect(noteDto.attributedTo == "http://localhost:8080/actors/goronfoter", "Property 'attributedTo' is not valid.")
            #expect(noteDto.url == "http://localhost:8080/@goronfoter/\(statuses.first?.stringId() ?? "")", "Property 'url' is not valid.")
        }
        
        @Test
        func `Status with only username and id should be returned for unauthorized`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "migolfoter")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "AP note 1", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let noteDto = try await application.getResponse(
                to: "/@migolfoter/\(statuses.first!.requireID())",
                version: .none,
                method: .GET,
                decodeTo: NoteDto.self
            )
            
            // Assert.
            #expect(noteDto.id == "http://localhost:8080/actors/migolfoter/statuses/\(statuses.first?.stringId() ?? "")", "Property 'id' is not valid.")
            #expect(noteDto.attachment?.count == 1, "Property 'attachment' is not valid.")
            #expect(noteDto.attributedTo == "http://localhost:8080/actors/migolfoter", "Property 'attributedTo' is not valid.")
            #expect(noteDto.url == "http://localhost:8080/@migolfoter/\(statuses.first?.stringId() ?? "")", "Property 'url' is not valid.")
            #expect(noteDto.to == ComplexType.multiple([ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")]), "Property 'to' is not valid.")
            #expect(noteDto.cc == ComplexType.multiple([ActorDto(id: "http://localhost:8080/actors/migolfoter/followers")]), "Property 'cc' is not valid.")
        }
        
        @Test
        func `Comment should contain replyTo in the response`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "anthonyfoter")
            let user2 = try await application.createUser(userName: "moiqfoter")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "AP note 1", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            let comment = try await application.replyStatus(user: user2, comment: "This is reply for status 1", status: statuses.first!)
            
            // Act.
            let noteDto = try await application.getResponse(
                to: "/@moiqfoter/\(comment.requireID())",
                version: .none,
                method: .GET,
                decodeTo: NoteDto.self
            )
            
            // Assert.
            #expect(noteDto.id == "http://localhost:8080/actors/moiqfoter/statuses/\(comment.stringId() ?? "")", "Property 'id' is not valid.")
            #expect(noteDto.attributedTo == "http://localhost:8080/actors/moiqfoter", "Property 'attributedTo' is not valid.")
            #expect(noteDto.url == "http://localhost:8080/@moiqfoter/\(comment.stringId() ?? "")", "Property 'url' is not valid.")
            #expect(noteDto.inReplyTo == "http://localhost:8080/actors/anthonyfoter/statuses/\(statuses.first?.stringId() ?? "")", "Property 'inReplyTo' is not valid.")
            #expect(noteDto.to == ComplexType.multiple([ActorDto(id: "http://localhost:8080/actors/moiqfoter/followers")]), "Property 'to' is not valid.")
            #expect(noteDto.cc == ComplexType.multiple([
                ActorDto(id: "https://www.w3.org/ns/activitystreams#Public"),
                ActorDto(id: "http://localhost:8080/actors/anthonyfoter")
            ]), "Property 'cc' is not valid.")
        }
        
        @Test
        func `Comment should contain mentions with correct activity pub link`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "gigifoter")
            let user2 = try await application.createUser(userName: "kikifoter")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "AP note 1", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            let comment = try await application.replyStatus(user: user2, comment: "@gigifoter This is reply for status 1", status: statuses.first!)
            
            // Act.
            let noteDto = try await application.getResponse(
                to: "/@kikifoter/\(comment.requireID())",
                version: .none,
                method: .GET,
                decodeTo: NoteDto.self
            )
            
            // Assert.
            #expect(noteDto.id == "http://localhost:8080/actors/kikifoter/statuses/\(comment.stringId() ?? "")", "Property 'id' is not valid.")
            #expect(noteDto.attributedTo == "http://localhost:8080/actors/kikifoter", "Property 'attributedTo' is not valid.")
            #expect(noteDto.url == "http://localhost:8080/@kikifoter/\(comment.stringId() ?? "")", "Property 'url' is not valid.")
            #expect(noteDto.inReplyTo == "http://localhost:8080/actors/gigifoter/statuses/\(statuses.first?.stringId() ?? "")", "Property 'inReplyTo' is not valid.")

            #expect(noteDto.tag == ComplexType.multiple([ NoteTagDto(type: "Mention", name: "@gigifoter@localhost:8080", href: "http://localhost:8080/actors/gigifoter") ]), "Property 'tag' is not valid.")
        }
        
        @Test
        func `Category should be returned as a tag`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "terryfoter")
            let category = try await application.getCategory(name: "Street")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "AP note 1", categoryId: category?.stringId(), amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let noteDto = try await application.getResponse(
                to: "/actors/trondfoter/statuses/\(statuses.first!.requireID())",
                version: .none,
                decodeTo: NoteDto.self
            )
            
            // Assert.
            #expect(noteDto.id == "http://localhost:8080/actors/terryfoter/statuses/\(statuses.first?.stringId() ?? "")", "Property 'id' is not valid.")
            #expect(noteDto.attachment?.count == 1, "Property 'attachment' is not valid.")
            #expect(noteDto.attributedTo == "http://localhost:8080/actors/terryfoter", "Property 'attributedTo' is not valid.")
            #expect(noteDto.url == "http://localhost:8080/@terryfoter/\(statuses.first?.stringId() ?? "")", "Property 'url' is not valid.")
            #expect(noteDto.tag == ComplexType.multiple([
                NoteTagDto(type: "Category", name: "Street", href: "http://localhost:8080/categories/Street")
            ]), "Property 'tag' should contain category.")
        }

        @Test
        func `Quiet public status should be returned for all supported urls`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "quietactivitypub")
            let attachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment])
            }

            let status = try await application.createStatus(user: user,
                                                            note: "QUIET ACTIVITY PUB",
                                                            attachmentIds: [attachment.stringId()!],
                                                            visibility: .quietPublic)

            // Act.
            let actorNoteDto = try await application.getResponse(
                to: "/actors/\(user.userName)/statuses/\(status.requireID())",
                version: .none,
                method: .GET,
                decodeTo: NoteDto.self
            )
            let shortNoteDto = try await application.getResponse(
                to: "/@\(user.userName)/\(status.requireID())",
                version: .none,
                method: .GET,
                decodeTo: NoteDto.self
            )
            let statusesNoteDto = try await application.getResponse(
                to: "/statuses/\(status.requireID())",
                version: .none,
                method: .GET,
                decodeTo: NoteDto.self
            )

            // Assert.
            #expect(actorNoteDto.id == "http://localhost:8080/actors/\(user.userName)/statuses/\(status.stringId() ?? "")",
                    "Status should be returned for '/actors/:name/statuses/:id'.")
            #expect(shortNoteDto.id == "http://localhost:8080/actors/\(user.userName)/statuses/\(status.stringId() ?? "")",
                    "Status should be returned for '/@:name/:id'.")
            #expect(statusesNoteDto.id == "http://localhost:8080/actors/\(user.userName)/statuses/\(status.stringId() ?? "")",
                    "Status should be returned for '/statuses/:id'.")
        }

        @Test
        func `Followers and mentioned statuses should be forbidden for all supported urls`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "privateactivitypub")
            let followersAttachment = try await application.createAttachment(user: user)
            let mentionedAttachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [followersAttachment, mentionedAttachment])
            }

            let followersStatus = try await application.createStatus(user: user,
                                                                     note: "FOLLOWERS AP HIDDEN",
                                                                     attachmentIds: [followersAttachment.stringId()!],
                                                                     visibility: .public)
            try await application.changeStatusVisibility(statusId: followersStatus.requireID(), visibility: .followers)
            let mentionedStatus = try await application.createStatus(user: user,
                                                                     note: "MENTIONED AP HIDDEN",
                                                                     attachmentIds: [mentionedAttachment.stringId()!],
                                                                     visibility: .public)
            try await application.changeStatusVisibility(statusId: mentionedStatus.requireID(), visibility: .mentioned)

            let followersStatusId = try followersStatus.requireID()
            let mentionedStatusId = try mentionedStatus.requireID()

            let followersPaths = [
                "/actors/\(user.userName)/statuses/\(followersStatusId)",
                "/@\(user.userName)/\(followersStatusId)",
                "/statuses/\(followersStatusId)"
            ]

            for path in followersPaths {
                let errorResponse = try await application.getErrorResponse(
                    to: path,
                    version: .none,
                    method: .GET
                )
                #expect(errorResponse.status == HTTPResponseStatus.forbidden,
                        "Followers status should be forbidden for '\(path)'.")
            }

            let mentionedPaths = [
                "/actors/\(user.userName)/statuses/\(mentionedStatusId)",
                "/@\(user.userName)/\(mentionedStatusId)",
                "/statuses/\(mentionedStatusId)"
            ]

            for path in mentionedPaths {
                let errorResponse = try await application.getErrorResponse(
                    to: path,
                    version: .none,
                    method: .GET
                )
                #expect(errorResponse.status == HTTPResponseStatus.forbidden,
                        "Mentioned status should be forbidden for '\(path)'.")
            }
        }
    }
}
