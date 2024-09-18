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

@Suite("POST /:id/unbookmark", .serialized, .tags(.statuses))
struct StatusesUnbookmarkActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Status should be unbookmarked for authorized user")
    func statusShouldBeUnbookmarkedForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await application.createUser(userName: "carinzuza")
        let user2 = try await application.createUser(userName: "adamzuza")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        try await application.bookmarkStatus(user: user2, status: statuses.first!)
        
        // Act.
        let statusDto = try application.getResponse(
            as: .user(userName: "adamzuza", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/unbookmark",
            method: .POST,
            decodeTo: StatusDto.self
        )
        
        // Assert.
        #expect(statusDto.id != nil, "Status wasn't created.")
        #expect(statusDto.bookmarked == false, "Status should be marked as unbookmarked.")
    }
        
    @Test("Not found should be returned if status not exists")
    func notFoundShouldBeReturnedIfStatusNotExists() async throws {

        // Arrange.
        _ = try await application.createUser(userName: "maxzuza")
        
        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "maxzuza", password: "p@ssword"),
            to: "/statuses/123456789/unbookmark",
            method: .POST
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    @Test("Unauthorized should be returned for not authorized user")
    func unauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await application.createUser(userName: "moiquezuza")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let errorResponse = try application.getErrorResponse(
            to: "/statuses/\(statuses.first!.requireID())/unbookmark",
            method: .POST
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
