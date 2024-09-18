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

@Suite("POST /:id/apply-content-warning", .serialized, .tags(.statuses))
struct StatusesApplyContentWarningActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Content warning should be added for authorized user")
    func contentWarningShouldBeAddedForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await application.createUser(userName: "brosgeblix")
        let user3 = try await application.createUser(userName: "romageblix")
        try await application.attach(user: user3, role: Role.moderator)
        
        let attachment = try await application.createAttachment(user: user1)
        let status = try await application.createStatus(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!], visibility: .mentioned)
        defer {
            application.clearFiles(attachments: [attachment])
        }
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "romageblix", password: "p@ssword"),
            to: "/statuses/\(status.requireID())/apply-content-warning",
            method: .POST,
            body: ContentWarningDto(contentWarning: "This is rude.")
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let statusAfterUpdate = try await application.getStatus(id: status.requireID())
        #expect(statusAfterUpdate?.contentWarning == "This is rude.", "Content warning should be applied.")
    }
    
    @Test("Forbidden should be returned ror regular user")
    func forbiddenShouldbeReturnedForRegularUser() async throws {
        
        // Arrange.
        let user1 = try await application.createUser(userName: "carinegeblix")
        _ = try await application.createUser(userName: "adamegeblix")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "adamegeblix", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/apply-content-warning",
            method: .POST,
            body: ContentWarningDto(contentWarning: "This is rude.")
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    @Test("Not found should be returned if status not exists")
    func notFoundShouldBeReturnedIfStatusNotExists() async throws {

        // Arrange.
        let user1 = try await application.createUser(userName: "maxegeblix")
        try await application.attach(user: user1, role: Role.moderator)
        
        // Act.
        let errorResponse = try application.getErrorResponse(
            as: .user(userName: "maxegeblix", password: "p@ssword"),
            to: "/statuses/123456789/apply-content-warning",
            method: .POST,
            data: ContentWarningDto(contentWarning: "This is rude.")
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    @Test("Unauthorized should be returned for not authorized user")
    func unauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await application.createUser(userName: "moiqueegeblix")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let errorResponse = try application.getErrorResponse(
            to: "/statuses/\(statuses.first!.requireID())/apply-content-warning",
            method: .POST,
            data: ContentWarningDto(contentWarning: "This is rude.")
        )

        // Assert.
        #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
