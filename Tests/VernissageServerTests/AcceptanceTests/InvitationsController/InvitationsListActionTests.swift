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
    
    @Suite("Invitations (GET /invitations)", .serialized, .tags(.invitations))
    struct InvitationsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `List of invitations should be returned for authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robingobix")
            
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            
            // Act.
            let invitations = try await application.getResponse(
                as: .user(userName: "robingobix", password: "p@ssword"),
                to: "/invitations",
                method: .GET,
                decodeTo: [InvitationDto].self
            )
            
            // Assert.
            #expect(invitations.count == 2, "Two invitations should be returned")
        }
        
        @Test
        func `List of invitations should not be returned when user is not authorized`() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/invitations", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
