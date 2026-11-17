//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("Statuses (POST /statuses/:id/bookmark)", .serialized, .tags(.statuses))
    struct StatusesBookmarkActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Bookmark through public boost should not grant access to restricted original`() async throws {
            // Arrange.
            let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            let owner = try await application.createUser(userName: "bo" + suffix)
            let booster = try await application.createUser(userName: "bb" + suffix)
            let actor = try await application.createUser(userName: "ba" + suffix)
            let original = try await application.createStatus(user: owner, note: "Original photo")
            let boost = try await application.createStatus(user: booster, note: nil, reblogId: original.requireID())
            original.visibility = .followers
            try await original.save(on: application.db)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: actor.userName, password: "p@ssword"),
                to: "/statuses/\(boost.requireID())/bookmark", method: .POST)

            // Assert.
            #expect(response.status == .forbidden)
        }

        @Test
        func `Bookmark of boosted status should belong to original status`() async throws {
            // Arrange.
            let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            let owner = try await application.createUser(userName: "bo" + suffix)
            let booster = try await application.createUser(userName: "bb" + suffix)
            let actor = try await application.createUser(userName: "ba" + suffix)
            let original = try await application.createStatus(user: owner, note: "Original photo")
            let boost = try await application.createStatus(user: booster, note: nil, reblogId: original.requireID())

            // Act.
            let response = try await application.getResponse(
                as: .user(userName: actor.userName, password: "p@ssword"),
                to: "/statuses/\(boost.requireID())/bookmark",
                method: .POST,
                decodeTo: StatusDto.self
            )

            // Assert.
            #expect(response.id == original.stringId())
            let bookmark = try #require(try await StatusBookmark.query(on: application.db)
                .filter(\.$user.$id == actor.requireID()).first())
            #expect(bookmark.$status.id == original.id)
        }

        @Test
        func `Status should be bookmarked for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinesso")
            _ = try await application.createUser(userName: "adamesso")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Bookmarked", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "adamesso", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/bookmark",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.bookmarked == true, "Status should be marked as bookmarked.")
        }
        
        @Test
        func `Forbidden should be returned for status with mentioned visibility`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "brosesso")
            _ = try await application.createUser(userName: "ingaesso")
            let attachment = try await application.createAttachment(user: user1)
            let status = try await application.createLegacyMentionedStatus(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "ingaesso", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/bookmark",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test
        func `Not found should be returned if status not exists`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "maxesso")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxesso", password: "p@ssword"),
                to: "/statuses/123456789/bookmark",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moiqueesso")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Bookmarked Unauthorized", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/bookmark",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
