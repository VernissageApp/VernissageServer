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
    
    @Suite("Reports (POST /reports)", .serialized, .tags(.reports))
    struct ReportsCreateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Report should be created by authorized user")
        func reportShouldBeCreatedByAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "lararomax")
            let user2 = try await application.createUser(userName: "romanromax")
            let reportDto = ReportRequestDto(reportedUserId: user2.stringId() ?? "", statusId: nil, comment: "Porn", forward: true, category: "Nude", ruleIds: [1, 2])
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "lararomax", password: "p@ssword"),
                to: "/reports",
                method: .POST,
                body: reportDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let report = try await application.getReport(userId: user1.requireID())
            #expect(report?.user.id == user1.id, "User id should be set correctly.")
            #expect(report?.reportedUser.id == user2.id, "Reported id should be set correctly.")
            #expect(report?.comment == "Porn", "Comment should be set correctly.")
            #expect(report?.forward == true, "Forward should be set correctly.")
            #expect(report?.category == "Nude", "Category should be set correctly.")
            #expect(report?.ruleIds == "1,2", "Rule ids should be set correctly.")
        }
        
        @Test("Report to comment should be created by authorized user")
        func reportToCommentShouldBeCreatedByAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "violetromax")
            let user2 = try await application.createUser(userName: "roseromax")
            
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Reports List", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            let comment = try await application.createStatus(user: user2, note: "Super rude comment", attachmentIds: [], replyToStatusId: statuses.first?.stringId())
            
            let reportDto = ReportRequestDto(reportedUserId: user2.stringId() ?? "", statusId: comment.stringId(), comment: "Rude comment", forward: true, category: "Rude", ruleIds: [1, 2])
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "violetromax", password: "p@ssword"),
                to: "/reports",
                method: .POST,
                body: reportDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
            let report = try await application.getReport(userId: user1.requireID())
            #expect(report?.user.id == user1.id, "User id should be set correctly.")
            #expect(report?.reportedUser.id == user2.id, "Reported id should be set correctly.")
            #expect(report?.comment == "Rude comment", "Comment should be set correctly.")
            #expect(report?.forward == true, "Forward should be set correctly.")
            #expect(report?.category == "Rude", "Category should be set correctly.")
            #expect(report?.ruleIds == "1,2", "Rule ids should be set correctly.")
            #expect(report?.$status.id == comment.id, "Rule ids should be set correctly.")
            #expect(report?.$mainStatus.id == statuses.first?.id, "Rule ids should be set correctly.")
        }
        
        @Test("Not found should be returned for not existing user")
        func notFoundShouldBeReturnedForNotExistingUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "eweromax")
            let reportDto = ReportRequestDto(reportedUserId: "1111", statusId: nil, comment: "Porn", forward: true, category: "Nude", ruleIds: [1, 2])
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "eweromax", password: "p@ssword"),
                to: "/reports",
                method: .POST,
                data: reportDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Not found should be returned for not existing status")
        func notFoundShouldBeReturnedForNotExistingStatus() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "trondromax")
            let user2 = try await application.createUser(userName: "tabiromax")
            let reportDto = ReportRequestDto(reportedUserId: user2.stringId() ?? "", statusId: "3431", comment: "Porn", forward: true, category: "Nude", ruleIds: [1, 2])
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "trondromax", password: "p@ssword"),
                to: "/reports",
                method: .POST,
                body: reportDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Unauthorize should be returnedd for not authorized user")
        func unauthorizeShouldBeReturneddForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "chrisromax")
            let reportDto = ReportRequestDto(reportedUserId: user.stringId() ?? "", statusId: nil, comment: "Porn", forward: true, category: "Nude", ruleIds: [1, 2])
            
            // Act.
            let response = try await application.sendRequest(
                to: "/reports",
                method: .POST,
                body: reportDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
