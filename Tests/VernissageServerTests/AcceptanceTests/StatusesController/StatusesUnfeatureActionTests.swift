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

@Suite("POST /:id/unfeature", .serialized, .tags(.statuses))
struct StatusesUnfeatureActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Status should be unfeatured for moderator")
    func statusShouldBeUnfeaturedForModerator() async throws {
        
        // Arrange.
        let user1 = try await application.createUser(userName: "maximrojon")
        let user2 = try await application.createUser(userName: "roxyrojon")
        try await application.attach(user: user2, role: Role.moderator)
        
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        _ = try await application.createFeaturedStatus(user: user2, status: statuses.first!)
        
        // Act.
        let statusDto = try application.getResponse(
            as: .user(userName: "roxyrojon", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/unfeature",
            method: .POST,
            decodeTo: StatusDto.self
        )
        
        // Assert.
        #expect(statusDto.id != nil, "Status wasn't created.")
        #expect(statusDto.featured == false, "Status should be marked as unfeatured.")
    }
    
    @Test("Forbidden should be returned for regular user")
    func forbiddenShouldbeReturnedForRegularUser() async throws {
        
        // Arrange.
        let user1 = try await application.createUser(userName: "carinrojon")
        let user2 = try await application.createUser(userName: "adamrojon")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        _ = try await application.createFeaturedStatus(user: user2, status: statuses.first!)
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "adamrojon", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/unfeature",
            method: .POST
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
        
    @Test("Not found should be returned if status not exists")
    func notFoundShouldBeReturnedIfStatusNotExists() async throws {

        // Arrange.
        let user1 = try await application.createUser(userName: "maxrojon")
        try await application.attach(user: user1, role: Role.moderator)
        
        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "maxrojon", password: "p@ssword"),
            to: "/statuses/123456789/unfeature",
            method: .POST
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    @Test("Unauthorized should be returned for not authorized user")
    func unauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await application.createUser(userName: "moiquerojon")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let errorResponse = try application.getErrorResponse(
            to: "/statuses/\(statuses.first!.requireID())/unfeature",
            method: .POST
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

