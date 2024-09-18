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

extension StatusesControllerTests {
    
    @Suite("GET /:id/reblogged", .serialized, .tags(.statuses))
    struct StatusesRebloggedActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("List of reblogged users should be returned for authorized user")
        func listOfRebloggedUsersShouldBeReturnedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinjorgi")
            let user2 = try await application.createUser(userName: "adamjorgi")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            _ = try await application.reblogStatus(user: user2, status: statuses.first!)
            
            // Act.
            let reblogged = try application.getResponse(
                as: .user(userName: "carinjorgi", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/reblogged",
                method: .GET,
                decodeTo: LinkableResultDto<UserDto>.self
            )
            
            // Assert.
            #expect(reblogged.data.count == 1, "All followers should be returned.")
        }
    }
}
