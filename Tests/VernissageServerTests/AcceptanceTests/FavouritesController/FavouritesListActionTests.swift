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
    
    @Suite("Favourites (GET /favourites)", .serialized, .tags(.favourites))
    struct FavouritesListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Favourites should not be returned for unauthorized user")
        func favouritesShouldNotBeReturnedForUnauthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "gregwuro")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Favourited note", amount: 4)
            _ = try await application.createStatusFavourite(user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try application.sendRequest(
                to: "/favourites?limit=2",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Favourites should be returned without params")
        func favouritesShouldBeReturnedWithoutParams() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "timwuro")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Favourited note", amount: 4)
            _ = try await application.createStatusFavourite(user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try application.getResponse(
                as: .user(userName: "timwuro", password: "p@ssword"),
                to: "/favourites?limit=2",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Favourited note 4", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Favourited note 3", "Second status is not visible.")
        }
        
        @Test("Favourites should be returned with minId")
        func favouritesShouldBeReturnedWithMinId() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "trondwuro")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Min favourited note", amount: 10)
            let favouritedStatuses = try await application.createStatusFavourite(user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try application.getResponse(
                as: .user(userName: "trondwuro", password: "p@ssword"),
                to: "/favourites?limit=2&minId=\(favouritedStatuses[5].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Min favourited note 8", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Min favourited note 7", "Second status is not visible.")
        }
        
        @Test("Favourites should be returned with maxId")
        func favouritesShouldBeReturnedWithMaxId() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "rickwuro")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Max favourited note", amount: 10)
            let favouritedStatuses = try await application.createStatusFavourite(user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try application.getResponse(
                as: .user(userName: "rickwuro", password: "p@ssword"),
                to: "/favourites?limit=2&maxId=\(favouritedStatuses[5].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Max favourited note 5", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Max favourited note 4", "Second status is not visible.")
        }
        
        @Test("Favourites should be returned with sinceId")
        func favouritesShouldBeReturnedWithSinceId() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "benwuro")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Since favourited note", amount: 10)
            let favouritedStatuses = try await application.createStatusFavourite(user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try application.getResponse(
                as: .user(userName: "benwuro", password: "p@ssword"),
                to: "/favourites?limit=20&sinceId=\(favouritedStatuses[5].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 4, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Since favourited note 10", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Since favourited note 9", "Second status is not visible.")
            #expect(statusesFromApi.data[2].note == "Since favourited note 8", "Third status is not visible.")
            #expect(statusesFromApi.data[3].note == "Since favourited note 7", "Fourth status is not visible.")
        }
    }
}
