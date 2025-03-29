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
    
    @Suite("ActivityPubShared (POST /shared/inbox [DeleteStatus])", .serialized, .tags(.shared))
    struct ActivityPubSharedDeleteStatusTests {
        var application: Application!
        
        init() async throws {
            self.application = try  await ApplicationManager.shared.application()
        }
        
        @Test("Status should be deleted when all correct data has been applied")
        func statusShouldBeDeletedWhenAllCorrectDataHasBeenApplied() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "vikidavin", generateKeys: true, isLocal: false)
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let createdStatus = try await Status.query(on: application.db).filter(\.$id == status.requireID()).first()
            createdStatus?.isLocal = false
            try await createdStatus?.save(on: application.db)
            
            let deleteTarget = ActivityPub.Notes.delete(user.activityPubProfile,
                                                        status.activityPubId,
                                                        user.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let statusFromDatabase = try await application.getStatus(id: status.requireID())
            #expect(statusFromDatabase == nil, "Status must be deleted from local datbase.")
        }
        
        @Test("Status should not be deleted when status is local")
        func statusShouldNotBeDeletedWhenStatusIsLocal() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "markdavin", generateKeys: true, isLocal: true)
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let deleteTarget = ActivityPub.Notes.delete(user.activityPubProfile,
                                                        status.activityPubId,
                                                        user.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let statusFromDatabase = try await application.getStatus(id: status.requireID())
            #expect(statusFromDatabase != nil, "Status must not be deleted from local datbase.")
        }
        
        @Test("Delete status should fail when date is outside time frame")
        func deleteStatusShouldFailWhenDateIsOutsideTimeFrame() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "marcindavin", generateKeys: true, isLocal: false)
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let createdStatus = try await Status.query(on: application.db).filter(\.$id == status.requireID()).first()
            createdStatus?.isLocal = false
            try await createdStatus?.save(on: application.db)
            
            let deleteTarget = ActivityPub.Notes.delete(user.activityPubProfile,
                                                        status.activityPubId,
                                                        user.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
            dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
            
            let dateString = dateFormatter.string(from: Date.now.addingTimeInterval(-600))
            
            var headers = deleteTarget.headers?.getHTTPHeaders() ?? HTTPHeaders()
            headers.replaceOrAdd(name: "date", value: dateString)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: headers,
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "badTimeWindow", "Error code should be equal 'badTimeWindow'.")
            #expect(errorResponse.error.reason == "ActivityPub signed request date '\(dateString)' is outside acceptable time window.")
            
            let statusFromDatabase = try await application.getStatus(id: status.requireID())
            #expect(statusFromDatabase != nil, "Status must not be deleted from local datbase.")
        }
    }
}
