//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit
import Fluent

final class ActivityPubSharedUnfavouriteStatusTests: CustomTestCase {
    
    func testStatusShouldBeUnfavouritedWhenAllCorrectDataHasBeenApplied() async throws {
        // Arrange.
        let user = try await User.create(userName: "vikitebox", generateKeys: true, isLocal: false)
        let attachment = try await Attachment.create(user: user)
        let status = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        let createdStatus = try await Status.query(on: SharedApplication.application().db).filter(\.$id == status.requireID()).first()
        createdStatus?.isLocal = false
        try await createdStatus?.save(on: SharedApplication.application().db)
        _ = try await StatusFavourite.create(statusId: createdStatus!.requireID(), userId: user.requireID())

        let unlikeTarget = ActivityPub.Notes.unlike("3412324",
                                                    user.activityPubProfile,
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
            headers: unlikeTarget.headers?.getHTTPHeaders() ?? .init(),
            body: unlikeTarget.httpBody!)
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        
        let statusFavouriteFromDatabase = try await StatusFavourite.get(statusId: status.requireID())
        XCTAssertNil(statusFavouriteFromDatabase, "Status must be unfavourited in local datbase.")
    }
        
    func testStatusShouldNotBeUnfavouritedWhenDateIsOutsideTimeFrame() async throws {
        // Arrange.
        let user = try await User.create(userName: "marcintebox", generateKeys: true, isLocal: false)
        let attachment = try await Attachment.create(user: user)
        let status = try await Status.create(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        let createdStatus = try await Status.query(on: SharedApplication.application().db).filter(\.$id == status.requireID()).first()
        createdStatus?.isLocal = false
        try await createdStatus?.save(on: SharedApplication.application().db)
        _ = try await StatusFavourite.create(statusId: createdStatus!.requireID(), userId: user.requireID())
        
        let unlikeTarget = ActivityPub.Notes.unlike("3412324",
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

        var headers = unlikeTarget.headers?.getHTTPHeaders() ?? HTTPHeaders()
        headers.replaceOrAdd(name: "date", value: dateString)
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/shared/inbox",
            version: .none,
            method: .POST,
            headers: headers,
            body: unlikeTarget.httpBody!)
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "badTimeWindow", "Error code should be equal 'badTimeWindow'.")
        XCTAssertEqual(errorResponse.error.reason, "ActivityPub signed request date '\(dateString)' is outside acceptable time window.")
        
        let statusFavouriteFromDatabase = try await StatusFavourite.get(statusId: status.requireID())
        XCTAssertNotNil(statusFavouriteFromDatabase, "Status must not be unfavourited in local datbase.")
    }
}
