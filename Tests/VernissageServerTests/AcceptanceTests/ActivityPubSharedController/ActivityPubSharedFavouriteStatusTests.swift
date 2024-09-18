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

extension ActivityPubSharedControllerTests {
    
    @Suite("POST /inbox [FavouriteStatus]", .serialized, .tags(.shared))
    struct ActivityPubSharedFavouriteStatusTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Status should be favourited when all correct data has been applied")
        func statusShouldBeFavouritedWhenAllCorrectDataHasBeenApplied() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "vikiropix", generateKeys: true, isLocal: false)
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let createdStatus = try await Status.query(on: application.db).filter(\.$id == status.requireID()).first()
            createdStatus?.isLocal = false
            try await createdStatus?.save(on: application.db)
            
            let likeTarget = ActivityPub.Notes.like("3412324",
                                                    user.activityPubProfile,
                                                    status.activityPubId,
                                                    user.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost")
            
            // Act.
            let response = try application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: likeTarget.headers?.getHTTPHeaders() ?? .init(),
                body: likeTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let statusFavouriteFromDatabase = try await application.getStatusFavourite(statusId: status.requireID())
            #expect(statusFavouriteFromDatabase != nil, "Status must be favourited in local datbase.")
        }
        
        @Test("Status should not be favourited when date is outside time frame")
        func testStatusShouldNotBeFavouritedWhenDateIsOutsideTimeFrame() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "marcinropix", generateKeys: true, isLocal: false)
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let createdStatus = try await Status.query(on: application.db).filter(\.$id == status.requireID()).first()
            createdStatus?.isLocal = false
            try await createdStatus?.save(on: application.db)
            
            let likeTarget = ActivityPub.Notes.like("3412324",
                                                    user.activityPubProfile,
                                                    status.activityPubId,
                                                    user.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
            dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
            
            let dateString = dateFormatter.string(from: Date.now.addingTimeInterval(-600))
            
            var headers = likeTarget.headers?.getHTTPHeaders() ?? HTTPHeaders()
            headers.replaceOrAdd(name: "date", value: dateString)
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: headers,
                body: likeTarget.httpBody!)
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "badTimeWindow", "Error code should be equal 'badTimeWindow'.")
            #expect(errorResponse.error.reason == "ActivityPub signed request date '\(dateString)' is outside acceptable time window.")
            
            let statusFavouriteFromDatabase = try await application.getStatusFavourite(statusId: status.requireID())
            #expect(statusFavouriteFromDatabase == nil, "Status must not be favourited in local datbase.")
        }
    }
}
