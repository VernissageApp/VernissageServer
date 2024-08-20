//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class ActivityPubSharedFollowTests: CustomTestCase {
        
    func testFollowShouldSuccessWhenAllCorrectDataHasBeenApplied() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "vikitewa", generateKeys: true)
        let user2 = try await User.create(userName: "ricktewa", generateKeys: true)

        let followTarget = ActivityPub.Users.follow(user1.activityPubProfile,
                                                    user2.activityPubProfile,
                                                    user1.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost",
                                                    231)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/shared/inbox",
            version: .none,
            method: .POST,
            headers: followTarget.headers?.getHTTPHeaders() ?? .init(),
            body: followTarget.httpBody!)
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")

        let follow = try await Follow.get(sourceId: user1.requireID(), targetId: user2.requireID())
        XCTAssertNotNil(follow, "Follow must be added to local datbase.")
    }
    
    func testFollowShouldFailWhenDateIsOutsideTimeFrame() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "tristewa", generateKeys: true)
        let user2 = try await User.create(userName: "jentewa", generateKeys: true)

        let followTarget = ActivityPub.Users.follow(user1.activityPubProfile,
                                                    user2.activityPubProfile,
                                                    user1.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost",
                                                    5234)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")

        let dateString = dateFormatter.string(from: Date.now.addingTimeInterval(-600))

        var headers = followTarget.headers?.getHTTPHeaders() ?? HTTPHeaders()
        headers.replaceOrAdd(name: "date", value: dateString)
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/shared/inbox",
            version: .none,
            method: .POST,
            headers: headers,
            body: followTarget.httpBody!)
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "badTimeWindow", "Error code should be equal 'badTimeWindow'.")
        XCTAssertEqual(errorResponse.error.reason, "ActivityPub signed request date '\(dateString)' is outside acceptable time window.")
        
        let follow = try await Follow.get(sourceId: user1.requireID(), targetId: user2.requireID())
        XCTAssertNil(follow, "Follow must not be added to local datbase.")
    }
    
    func testFollowShouldFailWhenDomainIsBlockedByInstance() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "darekurban", generateKeys: true)
        let user2 = try await User.create(userName: "artururban", generateKeys: true)

        let followTarget = ActivityPub.Users.follow(user1.activityPubProfile,
                                                    user2.activityPubProfile,
                                                    user1.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost",
                                                    523)
        
        try await InstanceBlockedDomain.clear()
        _ = try await InstanceBlockedDomain.create(domain: "localhost")
        
        // Act.
        _ = try SharedApplication.application().sendRequest(
            to: "/shared/inbox",
            version: .none,
            method: .POST,
            headers: followTarget.headers?.getHTTPHeaders() ?? .init(),
            body: followTarget.httpBody!)
        try await InstanceBlockedDomain.clear()
        
        // Assert.
        let follow = try await Follow.get(sourceId: user1.requireID(), targetId: user2.requireID())
        XCTAssertNil(follow, "Follow must not be added to local datbase.")
    }
    
    func testFollowShouldFailWhenDomainIsBlockedByUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "grzegorzkurban", generateKeys: true)
        let user2 = try await User.create(userName: "rafalurban", generateKeys: true)

        let followTarget = ActivityPub.Users.follow(user1.activityPubProfile,
                                                    user2.activityPubProfile,
                                                    user1.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost",
                                                    7473)
        
        try await UserBlockedDomain.clear()
        _ = try await UserBlockedDomain.create(userId: user2.requireID(), domain: "localhost")
        
        // Act.
        _ = try SharedApplication.application().sendRequest(
            to: "/shared/inbox",
            version: .none,
            method: .POST,
            headers: followTarget.headers?.getHTTPHeaders() ?? .init(),
            body: followTarget.httpBody!)
        try await UserBlockedDomain.clear()
        
        // Assert.
        let follow = try await Follow.get(sourceId: user1.requireID(), targetId: user2.requireID())
        XCTAssertNil(follow, "Follow must not be added to local datbase.")
    }
}
