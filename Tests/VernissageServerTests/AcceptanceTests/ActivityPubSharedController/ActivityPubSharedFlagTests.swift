//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("ActivityPubShared (POST /shared/inbox [Flag])", .serialized, .tags(.shared))
    struct ActivityPubSharedFlagTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Report should be created from incoming Flag for local user`() async throws {
            // Arrange.
            let reportingUser = try await application.createUser(userName: "flagremoteuser", generateKeys: true, isLocal: false)
            let reportedUser = try await application.createUser(userName: "flaglocaluser", generateKeys: true)
            
            let flagTarget = ActivityPub.Flag.create(
                "1",
                reportingUser.activityPubProfile,
                reportedUser.activityPubProfile,
                [],
                "Spam. Publikuje scam linki",
                reportingUser.privateKey!,
                "/shared/inbox",
                Constants.userAgent,
                "localhost"
            )
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: flagTarget.headers?.getHTTPHeaders() ?? .init(),
                body: flagTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let report = try await application.getReport(userId: reportingUser.requireID())
            #expect(report?.$reportedUser.id == reportedUser.id, "Reported user should be set.")
            #expect(report?.$status.id == nil, "Status should not be set.")
            #expect(report?.comment == "Spam. Publikuje scam linki", "Comment should be copied from Flag content.")
            #expect(report?.forward == false, "Incoming report should not be forwarded again.")
            #expect(report?.isLocal == false, "Incoming ActivityPub report should be marked as non-local.")
            #expect(report?.activityPubId == "\(reportingUser.activityPubProfile)#flags/1", "ActivityPub id should be saved.")
        }
        
        @Test
        func `Report should be created from incoming Flag for local status`() async throws {
            // Arrange.
            let reportingUser = try await application.createUser(userName: "flagremotestatus", generateKeys: true, isLocal: false)
            let reportedUser = try await application.createUser(userName: "flaglocalstatus", generateKeys: true)
            let attachment = try await application.createAttachment(user: reportedUser)
            let status = try await application.createStatus(user: reportedUser, note: "Reported note", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let flagTarget = ActivityPub.Flag.create(
                "2",
                reportingUser.activityPubProfile,
                reportedUser.activityPubProfile,
                [status.activityPubId],
                "Abusive. Reported status",
                reportingUser.privateKey!,
                "/shared/inbox",
                Constants.userAgent,
                "localhost"
            )
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: flagTarget.headers?.getHTTPHeaders() ?? .init(),
                body: flagTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let report = try await application.getReport(userId: reportingUser.requireID())
            #expect(report?.$reportedUser.id == reportedUser.id, "Reported user should be set from reported status owner.")
            #expect(report?.$status.id == status.id, "Status should be set from Flag object.")
            #expect(report?.comment == "Abusive. Reported status", "Comment should be copied from Flag content.")
            #expect(report?.isLocal == false, "Incoming ActivityPub report should be marked as non-local.")
            #expect(report?.activityPubId == "\(reportingUser.activityPubProfile)#flags/2", "ActivityPub id should be saved.")
        }
        
        @Test
        func `Admin report notification should be created for moderators when incoming Flag is processed`() async throws {
            // Arrange.
            let moderator = try await application.createUser(userName: "flagnotifymoderator")
            try await application.attach(user: moderator, role: Role.moderator)
            
            let reportingUser = try await application.createUser(userName: "flagnotifyremote", generateKeys: true, isLocal: false)
            let reportedUser = try await application.createUser(userName: "flagnotifylocal", generateKeys: true)
            
            let flagTarget = ActivityPub.Flag.create(
                "4",
                reportingUser.activityPubProfile,
                reportedUser.activityPubProfile,
                [],
                "Notification test",
                reportingUser.privateKey!,
                "/shared/inbox",
                Constants.userAgent,
                "localhost"
            )
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: flagTarget.headers?.getHTTPHeaders() ?? .init(),
                body: flagTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let notification = try await Notification.query(on: application.db)
                .filter(\.$notificationType == NotificationType.adminReport)
                .filter(\.$user.$id == moderator.requireID())
                .filter(\.$byUser.$id == reportedUser.requireID())
                .first()
            
            #expect(notification != nil, "Admin report notification should be created for moderator.")
        }
        
        @Test
        func `Duplicate incoming Flag should not create duplicate reports`() async throws {
            // Arrange.
            let reportingUser = try await application.createUser(userName: "flagduplicateremote", generateKeys: true, isLocal: false)
            let reportedUser = try await application.createUser(userName: "flagduplicatelocal", generateKeys: true)
            
            let flagTarget = ActivityPub.Flag.create(
                "3",
                reportingUser.activityPubProfile,
                reportedUser.activityPubProfile,
                [],
                "Duplicate report test",
                reportingUser.privateKey!,
                "/shared/inbox",
                Constants.userAgent,
                "localhost"
            )
            
            // Act.
            let firstResponse = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: flagTarget.headers?.getHTTPHeaders() ?? .init(),
                body: flagTarget.httpBody!)
            
            let secondResponse = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: flagTarget.headers?.getHTTPHeaders() ?? .init(),
                body: flagTarget.httpBody!)
            
            // Assert.
            #expect(firstResponse.status == HTTPResponseStatus.ok, "First response http status code should be ok (200).")
            #expect(secondResponse.status == HTTPResponseStatus.ok, "Second response http status code should be ok (200).")
            
            let activityPubId = "\(reportingUser.activityPubProfile)#flags/3"
            let reports = try await Report.query(on: application.db)
                .filter(\.$activityPubId == activityPubId)
                .all()
            
            #expect(reports.count == 1, "Only one report should exist for the same ActivityPub id.")
        }
    }
}
