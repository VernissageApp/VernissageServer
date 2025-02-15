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
    
    @Suite("Reports (GET /reports)", .serialized, .tags(.reports))
    struct ReportsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of reports should be returned for moderator user")
        func listOfReportsShouldBeReturnedForModeratorUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "robinrepix")
            try await application.attach(user: user1, role: Role.moderator)
            let user2 = try await application.createUser(userName: "martinrepix")
            
            _ = try await application.createReport(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
            _ = try await application.createReport(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 2.")
            
            // Act.
            let reports = try application.getResponse(
                as: .user(userName: "robinrepix", password: "p@ssword"),
                to: "/reports",
                method: .GET,
                decodeTo: PaginableResultDto<ReportDto>.self
            )
            
            // Assert.
            #expect(reports != nil, "Reports should be returned.")
            #expect(reports.data.count > 0, "Some reports should be returned.")
        }
        
        @Test("List of reports should be returned for administrator user")
        func listOfReportsShouldBeReturnedForAdministratorUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "wikirepix")
            try await application.attach(user: user1, role: Role.administrator)
            let user2 = try await application.createUser(userName: "gregrepix")
            
            _ = try await application.createReport(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
            _ = try await application.createReport(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 2.")
            
            // Act.
            let reports = try application.getResponse(
                as: .user(userName: "wikirepix", password: "p@ssword"),
                to: "/reports",
                method: .GET,
                decodeTo: PaginableResultDto<ReportDto>.self
            )
            
            // Assert.
            #expect(reports != nil, "Reports should be returned.")
            #expect(reports.data.count > 0, "Some reports should be returned.")
        }
        
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldbeReturnedForRegularUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "trelrepix")
            let user2 = try await application.createUser(userName: "mortenrepix")
            
            _ = try await application.createReport(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 1.")
            _ = try await application.createReport(userId: user1.requireID(), reportedUserId: user2.requireID(), statusId: nil, comment: "This is rude 2.")
            
            // Act.
            let response = try application.getErrorResponse(
                as: .user(userName: "trelrepix", password: "p@ssword"),
                to: "/reports",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("List of reports should not be returned when user is not authorized")
        func listOfReportsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Act.
            let response = try application.sendRequest(to: "/reports", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
