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
    
    @Suite("Exports (GET /bookmarks)", .serialized, .tags(.exports))
    struct BookmarksActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Bookmarks file should be returned for authorized user")
        func bookmarksFileShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "carinbofiol")
            let user2 = try await application.createUser(userName: "adambofiol")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Export bookamrk", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            try await application.bookmarkStatus(user: user2, status: statuses.first!)

            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "adambofiol", password: "p@ssword"),
                to: "/exports/bookmarks",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == .ok, "Success status code should be returned.")
            #expect(response.headers.contentDisposition?.value == .attachment, "Correct content disposition attachment should be set.")
            #expect(response.headers.contentDisposition?.filename == "bookmarks.csv", "Correct content disposition file should be set.")
            #expect(response.body.readableBytes > 0, "Content should be returned.")
        }
        
        @Test("Bookmarks file should not be returned for unauthorized user")
        func bookmakrsFileShouldNotBeReturnedForUnauthorizedUser() async throws {
            
            // Act.
            let response = try await application.sendRequest(
                to: "/exports/bookmarks",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
