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
    
    @Suite("Atom (GET /atom/hashtags/:hashtag)", .serialized, .tags(.atom))
    struct AtomHashtagsActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Atom feed with hashtags public statuses should be returned")
        func atomFeedWithHashtagsPublicStatusesShouldBeReturned() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(true))
            let user = try await application.createUser(userName: "henrytbopi")

            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Public note #blackandwhite", amount: 4)
            _ = try await application.createUserStatus(type: .owner, user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                to: "/atom/hashtags/blackandwhite",
                version: .none,
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            #expect(response.headers.contentType?.description == "application/atom+xml; charset=utf-8", "Response header should be set correctly.")
            #expect(response.body.string.starts(with: "<?xml") == true, "Correct XML should be returned (\(response.body.string)).")
        }
        
        @Test("Atom feed with hashtags public statuses should not be returned for not existing hashtag")
        func atomFeedWithHashtagsPublicStatusesShouldNotBeReturnedForNotExistingHashtag() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(true))
            
            // Act.
            let response = try await application.sendRequest(to: "/atom/hashtags/",
                                                       version: .none,
                                                       method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Atom feed with hashtags public statuses should not be returned when public access is disabled")
        func atomFeedWithHashtagsPublicStatusesShouldNotBeReturnedWhenPublicAccessIsDisabled() async throws {
            // Arrange.
            try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try await application.sendRequest(
                to: "/atom/hashtags/blackandwhite",
                version: .none,
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
