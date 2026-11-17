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
    
    @Suite("Statuses (POST /statuses/:id/unbookmark)", .serialized, .tags(.statuses))
    struct StatusesUnbookmarkActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Unbookmark through public boost should not grant access to restricted original`() async throws {
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
                to: "/statuses/\(boost.requireID())/unbookmark", method: .POST)

            // Assert.
            #expect(response.status == .forbidden)
        }

        @Test
        func `Unbookmark through boost should remove bookmark from original status`() async throws {
            // Arrange.
            let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            let owner = try await application.createUser(userName: "bo" + suffix)
            let booster = try await application.createUser(userName: "bb" + suffix)
            let actor = try await application.createUser(userName: "ba" + suffix)
            let original = try await application.createStatus(user: owner, note: "Original photo")
            let boost = try await application.createStatus(user: booster, note: nil, reblogId: original.requireID())
            try await application.bookmarkStatus(user: actor, status: original)

            // Act.
            let response = try await application.getResponse(
                as: .user(userName: actor.userName, password: "p@ssword"),
                to: "/statuses/\(boost.requireID())/unbookmark",
                method: .POST,
                decodeTo: StatusDto.self
            )

            // Assert.
            #expect(response.id == original.stringId())
            #expect(try await StatusBookmark.query(on: application.db)
                .filter(\.$user.$id == actor.requireID()).count() == 0)
        }

        @Test
        func `Status should be unbookmarked for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinzuza")
            let user2 = try await application.createUser(userName: "adamzuza")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unbookmark", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            try await application.bookmarkStatus(user: user2, status: statuses.first!)
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "adamzuza", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/unbookmark",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.bookmarked == false, "Status should be marked as unbookmarked.")
        }
        
        @Test
        func `Not found should be returned if status not exists`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "maxzuza")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxzuza", password: "p@ssword"),
                to: "/statuses/123456789/unbookmark",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moiquezuza")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unbookmark Unauthorized", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/unbookmark",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
