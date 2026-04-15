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
    
    @Suite("Reports (POST /reports/:id/send)", .serialized, .tags(.reports))
    struct ReportsSendActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Report should be marked as forwarded by administrator`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "adminreportsend")
            try await application.attach(user: user1, role: Role.administrator)
            let user2 = try await application.createUser(userName: "reportedreportsend")
            
            let report = try await application.createReport(
                userId: user1.requireID(),
                reportedUserId: user2.requireID(),
                statusId: nil,
                comment: "This should be sent.",
                forward: false
            )
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "adminreportsend", password: "p@ssword"),
                to: "/reports/\(report.stringId() ?? "")/send",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let reportFromDatabase = try await application.getReport(id: report.requireID())
            #expect(reportFromDatabase?.forward == true, "Report should be marked as forwarded.")
        }
        
        @Test
        func `Report should be marked as forwarded by moderator`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "modreportsend")
            try await application.attach(user: user1, role: Role.moderator)
            let user2 = try await application.createUser(userName: "modreportedreportsend")
            
            let report = try await application.createReport(
                userId: user1.requireID(),
                reportedUserId: user2.requireID(),
                statusId: nil,
                comment: "This should be sent.",
                forward: false
            )
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "modreportsend", password: "p@ssword"),
                to: "/reports/\(report.stringId() ?? "")/send",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let reportFromDatabase = try await application.getReport(id: report.requireID())
            #expect(reportFromDatabase?.forward == true, "Report should be marked as forwarded.")
        }
        
        @Test
        func `Forwarded report should stay forwarded`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "alreadyreportsend")
            try await application.attach(user: user1, role: Role.administrator)
            let user2 = try await application.createUser(userName: "alreadyreportedreportsend")
            
            let report = try await application.createReport(
                userId: user1.requireID(),
                reportedUserId: user2.requireID(),
                statusId: nil,
                comment: "This is already sent.",
                forward: true
            )
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "alreadyreportsend", password: "p@ssword"),
                to: "/reports/\(report.stringId() ?? "")/send",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let reportFromDatabase = try await application.getReport(id: report.requireID())
            #expect(reportFromDatabase?.forward == true, "Report should stay marked as forwarded.")
        }
        
        @Test
        func `Forbidden should be returned for regular user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "regularreportsend")
            let user2 = try await application.createUser(userName: "regularreportedreportsend")
            
            let report = try await application.createReport(
                userId: user1.requireID(),
                reportedUserId: user2.requireID(),
                statusId: nil,
                comment: "This should not be sent.",
                forward: false
            )
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "regularreportsend", password: "p@ssword"),
                to: "/reports/\(report.stringId() ?? "")/send",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            let reportFromDatabase = try await application.getReport(id: report.requireID())
            #expect(reportFromDatabase?.forward == false, "Report should not be marked as forwarded.")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "unauthreportsend")
            let user2 = try await application.createUser(userName: "unauthreportedreportsend")
            let report = try await application.createReport(
                userId: user1.requireID(),
                reportedUserId: user2.requireID(),
                statusId: nil,
                comment: "This should not be sent.",
                forward: false
            )
            
            // Act.
            let response = try await application.sendRequest(
                to: "/reports/\(report.stringId() ?? "")/send",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
            let reportFromDatabase = try await application.getReport(id: report.requireID())
            #expect(reportFromDatabase?.forward == false, "Report should not be marked as forwarded.")
        }
    }
}
