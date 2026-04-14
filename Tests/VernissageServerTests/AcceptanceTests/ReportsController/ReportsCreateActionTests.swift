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
        
        @Test
        func `Report should be created by authorized user`() async throws {
            
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
        
        @Test
        func `Report to comment should be created by authorized user`() async throws {
            
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

        @Test
        func `Admin report notification should be created when reported user is blocked by moderator`() async throws {
            
            // Arrange.
            let moderator = try await application.createUser(userName: "emilyromax")
            try await application.attach(user: moderator, role: Role.moderator)
            
            let reporter = try await application.createUser(userName: "louisromax")
            let reportedUser = try await application.createUser(userName: "simonromax")
            _ = try await application.createUserBlockedUser(userId: moderator.requireID(), blockedUserId: reportedUser.requireID(), reason: "")
            
            let reportDto = ReportRequestDto(reportedUserId: reportedUser.stringId() ?? "",
                                             statusId: nil,
                                             comment: "Spam",
                                             forward: false,
                                             category: "Spam",
                                             ruleIds: [])

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: reporter.userName, password: "p@ssword"),
                to: "/reports",
                method: .POST,
                body: reportDto
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")

            let notification = try await VernissageServer.Notification.query(on: application.db)
                .filter(\.$notificationType == NotificationType.adminReport)
                .filter(\.$user.$id == moderator.requireID())
                .filter(\.$byUser.$id == reportedUser.requireID())
                .first()

            #expect(notification != nil, "Admin notification should be created when reported user is blocked by moderator.")
        }
        
        @Test
        func `Not found should be returned for not existing user`() async throws {
            
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
        
        @Test
        func `Not found should be returned for not existing status`() async throws {
            
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
        
        @Test
        func `Unauthorize should be returnedd for not authorized user`() async throws {
            
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
