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
    
    @Suite("Archives (GET /archives)", .serialized, .tags(.archives))
    struct ArchivesListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of archives should be returned for authorized user")
        func listOfArchivesShouldBeReturnedForAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinterimp")
            _ = try await application.createArchive(userId: user.requireID())
            
            // Act.
            let archives = try await application.getResponse(
                as: .user(userName: "robinterimp", password: "p@ssword"),
                to: "/archives",
                method: .GET,
                decodeTo: [ArchiveDto].self
            )
            
            // Assert.
            #expect(archives != nil, "Archives should be returned.")
            #expect(archives.count == 1, "One archive should be returned.")
            #expect(archives.first?.status == .new, "Archive should have new status.")
        }
        
        @Test("Only user's list of archives should be returned")
        func onlyUserslistOfArchivesShouldBeReturned() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "annaterimp")
            let user2 = try await application.createUser(userName: "markterimp")
            _ = try await application.createArchive(userId: user1.requireID())
            _ = try await application.createArchive(userId: user2.requireID())
            
            // Act.
            let archives = try await application.getResponse(
                as: .user(userName: "annaterimp", password: "p@ssword"),
                to: "/archives",
                method: .GET,
                decodeTo: [ArchiveDto].self
            )
            
            // Assert.
            #expect(archives != nil, "Archives should be returned.")
            #expect(archives.count == 1, "One archive should be returned.")
            #expect(archives.first?.status == .new, "Archive should have new status.")
            #expect(archives.first?.user.id == user1.stringId(), "User should be owner of the archive.")
        }
        
        @Test("List of archives should not be returned when user is not authorized")
        func listOfArchivesShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/archives", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
