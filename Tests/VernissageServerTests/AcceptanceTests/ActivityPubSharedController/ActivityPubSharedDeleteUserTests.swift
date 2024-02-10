//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class ActivityPubSharedDeleteUserTests: CustomTestCase {
    
    func testAccountShouldBeDeletedWhenAllCorrectDataHasBeenApplied() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "vikirubens", generateKeys: true, isLocal: false)
        
        let deleteTarget = ActivityPub.Users.delete(user1.activityPubProfile,
                                                    user1.privateKey!,
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
        
        let user = try await User.get(id: user1.requireID())
        XCTAssertNil(user, "User must be deleted from local datbase.")
    }
    
    func testAccountShouldNotBeDeletedWhenAccountIsLocal() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "mikerubens", generateKeys: true, isLocal: true)
        
        let deleteTarget = ActivityPub.Users.delete(user1.activityPubProfile,
                                                    user1.privateKey!,
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
        
        let user = try await User.get(id: user1.requireID())
        XCTAssertNotNil(user, "User must not be deleted from local datbase.")
    }
    
    func testDeleteAcountShouldFailWhenDateIsOutsideTimeFrame() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "trisrubens", generateKeys: true, isLocal: false)

        let deleteTarget = ActivityPub.Users.delete(user1.activityPubProfile,
                                                    user1.privateKey!,
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
        
        let user = try await User.get(id: user1.requireID())
        XCTAssertNotNil(user, "User must not be deleted from local datbase.")
    }
}
