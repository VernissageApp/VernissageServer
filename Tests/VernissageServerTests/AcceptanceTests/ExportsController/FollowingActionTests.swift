//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("Exports (GET /following)", .serialized, .tags(.exports))
    struct FollowingActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Following file should be returned for authorized user")
        func followingFileShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictorbopox", generateKeys: true)
            let user2 = try await application.createUser(userName: "mariabopox", generateKeys: true)
                                    
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "wictorbopox", password: "p@ssword"),
                to: "/exports/following",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == .ok, "Success status code should be returned.")
            #expect(response.headers.contentDisposition?.value == .attachment, "Correct content disposition attachment should be set.")
            #expect(response.headers.contentDisposition?.filename == "follows.csv", "Correct content disposition file should be set.")
            #expect(response.body.readableBytes > 0, "Content should be returned.")
        }
        
        @Test("Following file should not be returned for unauthorized user")
        func followingFileShouldNotBeReturnedForUnauthorizedUser() async throws {
            
            // Act.
            let response = try application.sendRequest(
                to: "/exports/following",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
