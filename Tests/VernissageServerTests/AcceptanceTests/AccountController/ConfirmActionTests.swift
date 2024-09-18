//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Vapor
import Testing

@Suite("POST /email/confirm", .serialized, .tags(.account))
struct ConfirmActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }
    
    @Test("Account should be confirmed with correct confirmation guid")
    func accountShouldBeConfirmedWithCorrectConfirmationGuid() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "samanthasmith", emailWasConfirmed: false, emailConfirmationGuid: UUID().uuidString)
        let confirmEmailRequestDto = ConfirmEmailRequestDto(id: user.stringId()!, confirmationGuid: user.emailConfirmationGuid!)

        // Act.
        let response = try application.sendRequest(to: "/account/email/confirm", method: .POST, body: confirmEmailRequestDto)

        // Assert.
        let userAfterRequest = try await application.getUser(userName: "samanthasmith")
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        #expect(userAfterRequest.emailWasConfirmed == true, "Email is not confirmed.")
    }

    @Test("Account should not be confirmed with incorrect confirmation guid")
    func accountShouldNotBeConfirmedWithIncorrectConfirmationGuid() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "eriksmith", emailWasConfirmed: false, emailConfirmationGuid: UUID().uuidString)
        let confirmEmailRequestDto = ConfirmEmailRequestDto(id: user.stringId()!, confirmationGuid: UUID().uuidString)

        // Act.
        let response = try application.sendRequest(to: "/account/email/confirm", method: .POST, body: confirmEmailRequestDto)

        // Assert.
        let userAfterRequest = try await application.getUser(userName: "eriksmith")
        #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be ok (200).")
        #expect(userAfterRequest.emailWasConfirmed == false, "Email is confirmed.")
    }
}
