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
    
    @Suite("Reports (POST /reports/:id/close)", .serialized, .tags(.reports))
    struct ReportsCloseActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Report should be closed by administrator`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "robinroxit")
            try await application.attach(user: user1, role: Role.administrator)
            let user2 = try await application.createUser(userName: "martinroxit")
            
            let report = try await application.createReport(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "robinroxit", password: "p@ssword"),
                to: "/reports/\(report.stringId() ?? "")/close",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let reportFromDatabase = try await application.getReport(id: report.requireID())
            #expect(reportFromDatabase?.$considerationUser.id != nil, "Consideration user should be saved.");
            #expect(reportFromDatabase?.considerationDate != nil, "Consideration date should be saved.");
        }
        
        @Test
        func `Report should be closed by moderator`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "chrisroxit")
            try await application.attach(user: user1, role: Role.moderator)
            let user2 = try await application.createUser(userName: "evaroxit")
            
            let report = try await application.createReport(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "chrisroxit", password: "p@ssword"),
                to: "/reports/\(report.stringId() ?? "")/close",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let reportFromDatabase = try await application.getReport(id: report.requireID())
            #expect(reportFromDatabase?.$considerationUser.id != nil, "Consideration user should be saved.");
            #expect(reportFromDatabase?.considerationDate != nil, "Consideration date should be saved.");
        }
        
        @Test
        func `Forbidden should be returned for regular user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "trecroxit")
            let user2 = try await application.createUser(userName: "tnbqroxit")
            
            let report = try await application.createReport(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "trecroxit", password: "p@ssword"),
                to: "/reports/\(report.stringId() ?? "")/close",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "goblinroxit")
            let user2 = try await application.createUser(userName: "minroxit")
            let report = try await application.createReport(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/reports/\(report.stringId() ?? "")/close",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
