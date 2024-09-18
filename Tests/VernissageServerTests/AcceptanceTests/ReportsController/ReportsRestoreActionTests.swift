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

extension ReportsControllerTests {
    
    @Suite("GET /reports/:id/restore", .serialized, .tags(.reports))
    struct ReportsRestoreActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Report should be restored by administrator")
        func reportShouldBeRestoredByAdministrator() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "robinvimin")
            try await application.attach(user: user1, role: Role.administrator)
            let user2 = try await application.createUser(userName: "martinvimin")
            
            let report = try await application.createReport(
                userId: user1.requireID(),
                reportedUserId: user2.requireID(),
                statusId: nil,
                comment: "This is rude 1.",
                considerationDate: Date(),
                considerationUserId: user1.requireID()
            )
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "robinvimin", password: "p@ssword"),
                to: "/reports/\(report.stringId() ?? "")/restore",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let reportFromDatabase = try await application.getReport(id: report.requireID())
            #expect(reportFromDatabase?.$considerationUser.id == nil, "Consideration user should be reset.");
            #expect(reportFromDatabase?.considerationDate == nil, "Consideration date should be reset.");
        }
        
        @Test("Report should be restored by moderator")
        func reportShouldBeRestoredByModerator() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "chrisvimin")
            try await application.attach(user: user1, role: Role.moderator)
            let user2 = try await application.createUser(userName: "evavimin")
            
            let report = try await application.createReport(
                userId: user1.requireID(),
                reportedUserId: user2.requireID(),
                statusId: nil,
                comment: "This is rude 1.",
                considerationDate: Date(),
                considerationUserId: user1.requireID()
            )
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "chrisvimin", password: "p@ssword"),
                to: "/reports/\(report.stringId() ?? "")/restore",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let reportFromDatabase = try await application.getReport(id: report.requireID())
            #expect(reportFromDatabase?.$considerationUser.id == nil, "Consideration user should be reset.");
            #expect(reportFromDatabase?.considerationDate == nil, "Consideration date should be reset.");
        }
        
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldbeReturnedForRegularUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "trecvimin")
            let user2 = try await application.createUser(userName: "tnbqvimin")
            
            let report = try await application.createReport(
                userId: user1.requireID(),
                reportedUserId: user2.requireID(),
                statusId: nil,
                comment: "This is rude 1.",
                considerationDate: Date(),
                considerationUserId: user1.requireID()
            )
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "trecvimin", password: "p@ssword"),
                to: "/reports/\(report.stringId() ?? "")/restore",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Unauthorized should be returned for not authorized user")
        func unauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "goblinvimin")
            let user2 = try await application.createUser(userName: "minvimin")
            let report = try await application.createReport(
                userId: user1.requireID(),
                reportedUserId: user2.requireID(),
                statusId: nil,
                comment: "This is rude 1.",
                considerationDate: Date(),
                considerationUserId: user1.requireID()
            )
            
            // Act.
            let response = try application.sendRequest(
                to: "/reports/\(report.stringId() ?? "")/restore",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
