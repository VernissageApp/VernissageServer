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
    
    @Suite("Rss (GET /rss/users/:username)", .serialized, .tags(.rss))
    struct RssUserActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Rss feed with user's public statuses should be returned")
        func rssFeedWithUsersPublicStatusesShouldBeReturned() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "gregroxon")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Public note", amount: 4)
            _ = try await application.createUserStatus(type: .owner, user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                to: "/rss/users/@gregroxon",
                version: .none,
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            #expect(response.headers.contentType?.description == "application/rss+xml; charset=utf-8", "Response header should be set correctly.")
            #expect(response.body.string.starts(with: "<?xml") == true, "Correct XML should be returned (\(response.body.string)).")
        }
        
        @Test("Rss feed with user's public statuses should not be returned for not existing actor")
        func rssFeedWithUsersPublicStatusesShouldNotBeReturnedForNotExistingActor() async throws {
            
            // Act.
            let response = try await application.sendRequest(to: "/rss/users/@unknown",
                                                       version: .none,
                                                       method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
    }
}
