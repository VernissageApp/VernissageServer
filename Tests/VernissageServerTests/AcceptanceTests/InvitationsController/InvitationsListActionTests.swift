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

@Suite("GET /", .serialized, .tags(.invitations))
struct InvitationsListActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("List of invitations should be returned for authorized user")
    func listOfInvitationsShouldBeReturnedForAuthorizedUser() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "robingobix")

        _ = try await application.createInvitation(userId: user.requireID())
        _ = try await application.createInvitation(userId: user.requireID())
        
        // Act.
        let invitations = try application.getResponse(
            as: .user(userName: "robingobix", password: "p@ssword"),
            to: "/invitations",
            method: .GET,
            decodeTo: [InvitationDto].self
        )

        // Assert.
        #expect(invitations != nil, "Invitations should be returned.")
        #expect(invitations.count == 2, "Two invitations should be returned")
    }
    
    @Test("List of invitations should not be returned when user is not authorized")
    func listOfInvitationsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
        // Act.
        let response = try application.sendRequest(to: "/invitations", method: .GET)

        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
