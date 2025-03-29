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
    
    @Suite("Atom (GET /atom/categories/:category)", .serialized, .tags(.atom))
    struct AtomCategoriesActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Atom feed with categories public statuses should be returned")
        func atomFeedWithCategoriesPublicStatusesShouldBeReturned() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(true))
            
            let user = try await application.createUser(userName: "henrytrenio")
            let category = try await application.getCategory(name: "Abstract")!

            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Public note", categoryId: category.stringId(), amount: 4)
            _ = try await application.createUserStatus(type: .owner, user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                to: "/atom/categories/Abstract",
                version: .none,
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            #expect(response.headers.contentType?.description == "application/atom+xml; charset=utf-8", "Response header should be set correctly.")
            #expect(response.body.string.starts(with: "<?xml") == true, "Correct XML should be returned (\(response.body.string)).")
        }
        
        @Test("Atom feed with categories public statuses should not be returned for not existing category")
        func atomFeedWithCategoriesPublicStatusesShouldNotBeReturnedForNotExistingCategory() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(true))
            
            // Act.
            let response = try await application.sendRequest(to: "/atom/categories/unknown",
                                                       version: .none,
                                                       method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Atom feed with categories public statuses should not be returned when public access is disabled")
        func atomFeedWithCategoriesPublicStatusesShouldNotBeReturnedWhenPublicAccessIsDisabled() async throws {
            // Arrange.
            try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try await application.sendRequest(to: "/atom/categories/unknown",
                                                       version: .none,
                                                       method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
