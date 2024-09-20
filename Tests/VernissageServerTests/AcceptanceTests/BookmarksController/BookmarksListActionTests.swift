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
    
    @Suite("Bookmarks (GET /bookmarks)", .serialized, .tags(.bookmarks))
    struct BookmarksListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Bookmarks should not be returned for unauthorized user")
        func bookmarksShouldNotBeReturnedForUnauthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "gregfoko")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Bookmarked note", amount: 4)
            _ = try await application.createStatusBookmark(user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try application.sendRequest(
                to: "/bookmarks?limit=2",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Bookmarks should be returned without params")
        func bookmarksShouldBeReturnedWithoutParams() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "timfoko")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Bookmarked note", amount: 4)
            _ = try await application.createStatusBookmark(user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try application.getResponse(
                as: .user(userName: "timfoko", password: "p@ssword"),
                to: "/bookmarks?limit=2",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Bookmarked note 4", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Bookmarked note 3", "Second status is not visible.")
        }
        
        @Test("Bookmarks should be returned with minId")
        func bookmarksShouldBeReturnedWithMinId() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "trondfoko")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Min bookmarked note", amount: 10)
            let bookmarkedStatuses = try await application.createStatusBookmark(user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try application.getResponse(
                as: .user(userName: "trondfoko", password: "p@ssword"),
                to: "/bookmarks?limit=2&minId=\(bookmarkedStatuses[5].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Min bookmarked note 8", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Min bookmarked note 7", "Second status is not visible.")
        }
        
        @Test("Bookmarks should be returned with maxId")
        func bookmarksShouldBeReturnedWithMaxId() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "rickfoko")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Max bookmarked note", amount: 10)
            let bookmarkedStatuses = try await application.createStatusBookmark(user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try application.getResponse(
                as: .user(userName: "rickfoko", password: "p@ssword"),
                to: "/bookmarks?limit=2&maxId=\(bookmarkedStatuses[5].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Max bookmarked note 5", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Max bookmarked note 4", "Second status is not visible.")
        }
        
        @Test("Bookmarks should be returned with sinceId")
        func bookmarksShouldBeReturnedWithSinceId() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "benfoko")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Since bookmarked note", amount: 10)
            let bookmarkedStatuses = try await application.createStatusBookmark(user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try application.getResponse(
                as: .user(userName: "benfoko", password: "p@ssword"),
                to: "/bookmarks?limit=20&sinceId=\(bookmarkedStatuses[5].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 4, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Since bookmarked note 10", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Since bookmarked note 9", "Second status is not visible.")
            #expect(statusesFromApi.data[2].note == "Since bookmarked note 8", "Third status is not visible.")
            #expect(statusesFromApi.data[3].note == "Since bookmarked note 7", "Fourth status is not visible.")
        }
    }
}
