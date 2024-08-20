//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit
import Fluent

final class ActivityPubSharedDeleteStatusTests: CustomTestCase {
    
    func testStatusShouldBeDeletedWhenAllCorrectDataHasBeenApplied() async throws {
        // Arrange.
        let user = try await User.create(userName: "vikidavin", generateKeys: true, isLocal: false)
        let attachment = try await Attachment.create(user: user)
        let status = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        let createdStatus = try await Status.query(on: SharedApplication.application().db).filter(\.$id == status.requireID()).first()
        createdStatus?.isLocal = false
        try await createdStatus?.save(on: SharedApplication.application().db)

        let deleteTarget = ActivityPub.Notes.delete(user.activityPubProfile,
                                                    status.activityPubId,
                                                    user.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/shared/inbox",
            version: .none,
            method: .POST,
            headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
            body: deleteTarget.httpBody!)
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        
        let statusFromDatabase = try await Status.get(id: status.requireID())
        XCTAssertNil(statusFromDatabase, "Status must be deleted from local datbase.")
    }
    
    func testStatusShouldNotBeDeletedWhenStatusIsLocal() async throws {
        // Arrange.
        let user = try await User.create(userName: "markdavin", generateKeys: true, isLocal: true)
        let attachment = try await Attachment.create(user: user)
        let status = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        let deleteTarget = ActivityPub.Notes.delete(user.activityPubProfile,
                                                    status.activityPubId,
                                                    user.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/shared/inbox",
            version: .none,
            method: .POST,
            headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
            body: deleteTarget.httpBody!)
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        
        let statusFromDatabase = try await Status.get(id: status.requireID())
        XCTAssertNotNil(statusFromDatabase, "Status must not be deleted from local datbase.")
    }
    
    func testDeleteStatusShouldFailWhenDateIsOutsideTimeFrame() async throws {
        // Arrange.
        let user = try await User.create(userName: "marcindavin", generateKeys: true, isLocal: false)
        let attachment = try await Attachment.create(user: user)
        let status = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        let createdStatus = try await Status.query(on: SharedApplication.application().db).filter(\.$id == status.requireID()).first()
        createdStatus?.isLocal = false
        try await createdStatus?.save(on: SharedApplication.application().db)
        
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
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/shared/inbox",
            version: .none,
            method: .POST,
            headers: headers,
            body: deleteTarget.httpBody!)
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "badTimeWindow", "Error code should be equal 'badTimeWindow'.")
        XCTAssertEqual(errorResponse.error.reason, "ActivityPub signed request date '\(dateString)' is outside acceptable time window.")
        
        let statusFromDatabase = try await Status.get(id: status.requireID())
        XCTAssertNotNil(statusFromDatabase, "Status must not be deleted from local datbase.")
    }
}
