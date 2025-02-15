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
    
    @Suite("ActivityPubShared (POST /shared/inbox [DeleteUser])", .serialized, .tags(.shared))
    struct ActivityPubSharedDeleteUserTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Account should be deleted when all correct data has been applied")
        func accountShouldBeDeletedWhenAllCorrectDataHasBeenApplied() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "vikirubens", generateKeys: true, isLocal: false)
            
            let deleteTarget = ActivityPub.Users.delete(user1.activityPubProfile,
                                                        user1.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")
            
            // Act.
            let response = try application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let user = try await application.getUser(id: user1.requireID())
            #expect(user == nil, "User must be deleted from local datbase.")
        }
        
        @Test("Account should not be deleted when account is local")
        func accountShouldNotBeDeletedWhenAccountIsLocal() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "mikerubens", generateKeys: true, isLocal: true)
            
            let deleteTarget = ActivityPub.Users.delete(user1.activityPubProfile,
                                                        user1.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")
            
            // Act.
            let response = try application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let user = try await application.getUser(id: user1.requireID())
            #expect(user != nil, "User must not be deleted from local datbase.")
        }
        
        @Test("Delete acount should fail when date is outside time frame")
        func deleteAcountShouldFailWhenDateIsOutsideTimeFrame() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "trisrubens", generateKeys: true, isLocal: false)
            
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
            let errorResponse = try application.getErrorResponse(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: headers,
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "badTimeWindow", "Error code should be equal 'badTimeWindow'.")
            #expect(errorResponse.error.reason == "ActivityPub signed request date '\(dateString)' is outside acceptable time window.")
            
            let user = try await application.getUser(id: user1.requireID())
            #expect(user != nil, "User must not be deleted from local datbase.")
        }
    }
}
