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
    
    @Suite("Statuses (GET /statuses/:id/favourited)", .serialized, .tags(.statuses))
    struct StatusesFavouritedActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of favourited users should be returned for authorized user")
        func listOfFavouritedUsersShouldBeReturnedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinrovik")
            let user2 = try await application.createUser(userName: "adamrovik")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Favourited List", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            _ = try await application.favouriteStatus(user: user2, status: statuses.first!)
            
            // Act.
            let reblogged = try application.getResponse(
                as: .user(userName: "carinrovik", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/favourited",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(reblogged.data.count == 1, "All followers should be returned.")
        }
    }
}
