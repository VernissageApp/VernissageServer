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
    
    @Suite("Search (GET /search)", .serialized, .tags(.search))
    struct SearchActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Search result should be returned when local account has been specidfied")
        func searchResultShouldBeReturnedWhenLocalAccountHasBeenSpecidfied() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "trondfinder")
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "trondfinder", password: "p@ssword"),
                to: "/search?query=admin",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.users != nil, "Users should be returned.")
            #expect((searchResultDto.users?.count ?? 0) > 0, "At least one user should be returned by the search.")
            #expect(searchResultDto.users?.first(where: { $0.userName == "admin" }) != nil, "Admin account should be returned.")
        }
        
        @Test("Search result should be returned when local account has been specidfied with hostname")
        func searchResultShouldBeReturnedWhenLocalAccountHasBeenSpecidfiedWithHostname() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "karolfinder")
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "karolfinder", password: "p@ssword"),
                to: "/search?query=admin@localhost",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.users != nil, "Users should be returned.")
            #expect((searchResultDto.users?.count ?? 0) > 0, "At least one user should be returned by the search.")
            #expect(searchResultDto.users?.first(where: { $0.userName == "admin" }) != nil, "Admin account should be returned.")
        }
        
        @Test("Search result should be returned when local account has been specidfied with @ prefix")
        func searchResultShouldBeReturnedWhenLocalAccountHasBeenSpecidfiedWithAtPrefix() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "eliaszfinder")
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "eliaszfinder", password: "p@ssword"),
                to: "/search?query=@admin",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.users != nil, "Users should be returned.")
            #expect((searchResultDto.users?.count ?? 0) > 0, "At least one user should be returned by the search.")
            #expect(searchResultDto.users?.first(where: { $0.userName == "admin" }) != nil, "Admin account should be returned.")
        }
        
        @Test("Search result should be returned when existing hashtag has been specidfied")
        func searchResultShouldBeReturnedWhenExistingHashtagHasBeenSpecidfied() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "mikifinder")
            try await application.createTrendingHashtag(trendingPeriod: .yearly, hashtag: "nature")
            try await application.createTrendingHashtag(trendingPeriod: .yearly, hashtag: "naturePhotography")
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "mikifinder", password: "p@ssword"),
                to: "/search?query=nature&type=hashtags",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.hashtags != nil, "Hashtags should be returned.")
            #expect((searchResultDto.hashtags?.count ?? 0) >= 2, "At least two hashtags should be returned by the search.")
        }
        
        @Test("Search result should be returned when existing status has been specidfied")
        func searchResultShouldBeReturnedWhenExistingStatusHasBeenSpecidfied() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "yorkifinder")

            let (_, attachments) = try await application.createStatuses(user: user, notePrefix: "This is wrocław photo", amount: 3)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "yorkifinder", password: "p@ssword"),
                to: "/search?query=wrocław&type=statuses",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.statuses != nil, "Hashtags should be returned.")
            #expect((searchResultDto.statuses?.count ?? 0) >= 3, "At least two statuses should be returned by the search.")
        }
        
        @Test("Empty search result should be returned when local account has not found")
        func emptySearchResultShouldBeReturnedWhenLocalAccountHasNotFound() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "ronaldfinder")
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "ronaldfinder", password: "p@ssword"),
                to: "/search?query=notfounded",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.users != nil, "Users should be returned.")
            #expect((searchResultDto.users?.count ?? 0) == 0, "Empty list should be returned.")
        }
        
        @Test("Empty search result should be returned when query has not been specified")
        func emptySearchResultShouldBeReturnedWhenQueryHasNotBeenSpecified() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "filipfinder")
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "filipfinder", password: "p@ssword"),
                to: "/search?query=",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.users != nil, "Users should be returned.")
            #expect((searchResultDto.users?.count ?? 0) == 0, "Empty list should be returned.")
        }
        
        @Test("Search results should not be returned when query is not specified")
        func searchResultsShouldNotBeReturnedWhenQueryIsNotSpecified() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "vikifinder")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "vikifinder", password: "p@ssword"),
                to: "/search",
                method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        }
        
        @Test("Search results should not be returned when user is not authorized")
        func searchResultsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/search?query=admin", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
