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
    
    @Suite("Atom (GET /atom/featured", .serialized, .tags(.atom))
    struct AtomFeaturedActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Atom feed with featured public statuses should be returned")
        func atomFeedWithFeaturedPublicStatusesShouldBeReturned() async throws {
            // Arrange.
            try await application.updateSetting(key: .showEditorsChoiceForAnonymous, value: .boolean(true))
            
            // Act.
            let response = try application.sendRequest(
                to: "/atom/featured",
                version: .none,
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            #expect(response.headers.contentType?.description == "application/atom+xml; charset=utf-8", "Response header should be set correctly.")
            #expect(response.body.string.starts(with: "<?xml") == true, "Correct XML should be returned (\(response.body.string)).")
        }
        
        @Test("Atom feed with featured public statuses should not be returned when public access is disabled")
        func atomFeedWithFeaturedPublicStatusesShouldNotBeReturnedWhenPublicAccessIsDisabled() async throws {
            // Arrange.
            try await application.updateSetting(key: .showEditorsChoiceForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try application.sendRequest(
                to: "/atom/featured",
                version: .none,
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
