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
    
    @Suite("ActivityPubShared (POST /shared/inbox [Follow])", .serialized, .tags(.shared))
    struct ActivityPubSharedFollowTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Follow should success when all correct data has been applied`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "vikitewa", generateKeys: true)
            let user2 = try await application.createUser(userName: "ricktewa", generateKeys: true)
            
            let followTarget = ActivityPub.Users.follow(user1.activityPubProfile,
                                                        user2.activityPubProfile,
                                                        user1.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost",
                                                        231)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: followTarget.headers?.getHTTPHeaders() ?? .init(),
                body: followTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let follow = try await application.getFollow(sourceId: user1.requireID(), targetId: user2.requireID())
            #expect(follow != nil, "Follow must be added to local datbase.")
        }
        
        @Test
        func `Follow should be rejected when target account has movedTo set`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "movedfollower", generateKeys: true)
            let user2 = try await application.createUser(userName: "movedtargetlocal", generateKeys: true)
            let user3 = try await application.createUser(userName: "moveddestination", generateKeys: true)
            user2.$movedTo.id = try user3.requireID()
            try await user2.save(on: application.db)
            
            let followTarget = ActivityPub.Users.follow(user1.activityPubProfile,
                                                        user2.activityPubProfile,
                                                        user1.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost",
                                                        6621)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: followTarget.headers?.getHTTPHeaders() ?? .init(),
                body: followTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let follow = try await application.getFollow(sourceId: user1.requireID(), targetId: user2.requireID())
            #expect(follow == nil, "Follow must not be added to local datbase for moved account.")
        }
        
        @Test
        func `Follow should fail when date is outside time frame`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "tristewa", generateKeys: true)
            let user2 = try await application.createUser(userName: "jentewa", generateKeys: true)
            
            let followTarget = ActivityPub.Users.follow(user1.activityPubProfile,
                                                        user2.activityPubProfile,
                                                        user1.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost",
                                                        5234)
            
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
            dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
            
            let dateString = dateFormatter.string(from: Date.now.addingTimeInterval(-600))
            
            var headers = followTarget.headers?.getHTTPHeaders() ?? HTTPHeaders()
            headers.replaceOrAdd(name: "date", value: dateString)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: headers,
                body: followTarget.httpBody!)
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "badTimeWindow", "Error code should be equal 'badTimeWindow'.")
            #expect(errorResponse.error.reason == "ActivityPub signed request date '\(dateString)' is outside acceptable time window.")
            
            let follow = try await application.getFollow(sourceId: user1.requireID(), targetId: user2.requireID())
            #expect(follow == nil, "Follow must not be added to local datbase.")
        }
        
        @Test
        func `Follow should fail when domain is blocked by instance`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "darekurban", generateKeys: true)
            let user2 = try await application.createUser(userName: "artururban", generateKeys: true)
            
            let followTarget = ActivityPub.Users.follow(user1.activityPubProfile,
                                                        user2.activityPubProfile,
                                                        user1.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost",
                                                        523)
            
            try await application.clearInstanceBlockedDomain()
            _ = try await application.createInstanceBlockedDomain(domain: "localhost")
            
            // Act.
            _ = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: followTarget.headers?.getHTTPHeaders() ?? .init(),
                body: followTarget.httpBody!)
            try await application.clearInstanceBlockedDomain()
            
            // Assert.
            let follow = try await application.getFollow(sourceId: user1.requireID(), targetId: user2.requireID())
            #expect(follow == nil, "Follow must not be added to local datbase.")
        }
        
        @Test
        func `Follow should fail when domain is blocked by user`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "grzegorzkurban", generateKeys: true)
            let user2 = try await application.createUser(userName: "rafalurban", generateKeys: true)
            
            let followTarget = ActivityPub.Users.follow(user1.activityPubProfile,
                                                        user2.activityPubProfile,
                                                        user1.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost",
                                                        7473)
            
            try await application.clearUserBlockedDomain()
            _ = try await application.createUserBlockedDomain(userId: user2.requireID(), domain: "localhost")
            
            // Act.
            _ = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: followTarget.headers?.getHTTPHeaders() ?? .init(),
                body: followTarget.httpBody!)
            try await application.clearUserBlockedDomain()
            
            // Assert.
            let follow = try await application.getFollow(sourceId: user1.requireID(), targetId: user2.requireID())
            #expect(follow == nil, "Follow must not be added to local datbase.")
        }
    }
}
