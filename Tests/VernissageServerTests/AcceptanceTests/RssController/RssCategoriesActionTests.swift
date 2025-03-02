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
    
    @Suite("Rss (GET /rss/categories/:category)", .serialized, .tags(.rss))
    struct RssCategoriesActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Rss feed with categories public statuses should be returned")
        func rssFeedWithCategoriesPublicStatusesShouldBeReturned() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(true))
            
            let user = try await application.createUser(userName: "henrygopo")
            let category = try await application.getCategory(name: "Abstract")!

            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Public note", categoryId: category.stringId(), amount: 4)
            _ = try await application.createUserStatus(type: .owner, user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try application.sendRequest(
                to: "/rss/categories/Abstract",
                version: .none,
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            #expect(response.headers.contentType?.description == "application/rss+xml; charset=utf-8", "Response header should be set correctly.")
            #expect(response.body.string.starts(with: "<?xml") == true, "Correct XML should be returned (\(response.body.string)).")
        }
        
        @Test("Rss feed with categories public statuses should not be returned for not existing category")
        func rssFeedWithCategoriesPublicStatusesShouldNotBeReturnedForNotExistingCategory() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(true))
            
            // Act.
            let response = try application.sendRequest(to: "/rss/categories/unknown",
                                                       version: .none,
                                                       method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Rss feed with categories public statuses should not be returned when public access is disabled")
        func rssFeedWithCategoriesPublicStatusesShouldNotBeReturnedWhenPublicAccessIsDisabled() async throws {
            // Arrange.
            try await application.updateSetting(key: .showCategoriesForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try application.sendRequest(to: "/rss/categories/unknown",
                                                       version: .none,
                                                       method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
