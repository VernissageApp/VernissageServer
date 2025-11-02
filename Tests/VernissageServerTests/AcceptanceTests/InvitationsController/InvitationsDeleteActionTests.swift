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
    
    @Suite("Invitations (DELETE /invitations/:id)", .serialized, .tags(.invitations))
    struct InvitationsDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Invitation should be deleted for authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robintermit")
            let invitation = try await application.createInvitation(userId: user.requireID())
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "robintermit", password: "p@ssword"),
                to: "/invitations/\(invitation.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let invitations = try await application.getAllInvitations(userId: user.requireID())
            #expect(invitations.count == 0, "Invitation should be deleted")
        }
        
        @Test
        func `Invitation should not be deleted for already used invitation`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "trondtermit")
            let user2 = try await application.createUser(userName: "borquetermit")
            let invitation = try await application.createInvitation(userId: user1.requireID())
            try await application.set(invitation: invitation, invitedId: user2.requireID())
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "trondtermit", password: "p@ssword"),
                to: "/invitations/\(invitation.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "cannotDeleteUsedInvitation", "Error code should be equal 'cannotDeleteUsedInvitation'.")
        }
        
        @Test
        func `Invitation should not be deleted for other authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "martintermit")
            _ = try await application.createUser(userName: "christermit")
            let invitation = try await application.createInvitation(userId: user1.requireID())
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "christermit", password: "p@ssword"),
                to: "/invitations/\(invitation.stringId() ?? "")",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Invitation should not be generated when user is not authorized`() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/invitations/123", method: .DELETE)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
