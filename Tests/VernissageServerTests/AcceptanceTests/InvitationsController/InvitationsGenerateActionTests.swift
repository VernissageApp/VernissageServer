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
    
    @Suite("Invitations (POST /invitations/generate)", .serialized, .tags(.invitations))
    struct InvitationsGenerateActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Invitation should be generated for authorized user")
        func invitationShouldBeGeneratedForAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "robinfrux")
            
            // Act.
            let invitation = try application.getResponse(
                as: .user(userName: "robinfrux", password: "p@ssword"),
                to: "/invitations/generate",
                method: .POST,
                decodeTo: InvitationDto.self
            )
            
            // Assert.
            #expect(invitation != nil, "Invitation should be generated.")
        }
        
        @Test("Invitation should not be generated when maximum number of invitation has been generated")
        func invitationShouldNtBeGeneratedWhenMaximumNumberOfInvitationHasBeenGenerated() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "georgefrux")
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "georgefrux", password: "p@ssword"),
                to: "/invitations/generate",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "maximumNumberOfInvitationsGenerated", "Error code should be equal 'maximumNumberOfInvitationsGenerated'.")
        }
        
        @Test("Aadministrator should generate invitation when maximum number of invitations has been generated")
        func administratorShouldGenerateInvitationWhenMaximumNumberOfInvitationsHasBeenGenerated() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "yorifrux")
            try await application.attach(user: user, role: Role.administrator)

            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            _ = try await application.createInvitation(userId: user.requireID())
            
            // Act.
            let invitation = try application.getResponse(
                as: .user(userName: "yorifrux", password: "p@ssword"),
                to: "/invitations/generate",
                method: .POST,
                decodeTo: InvitationDto.self
            )
            
            // Assert.
            #expect(invitation != nil, "Invitation should be generated.")
        }
        
        @Test("Invitation should not be generated when user is not authorized")
        func invitationShouldNotBeGeneratedWhenUserIsNotAuthorized() async throws {
            // Act.
            let response = try application.sendRequest(to: "/invitations/generate", method: .POST)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
