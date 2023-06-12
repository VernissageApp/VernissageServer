//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import Fluent

final class RegisterActionTests: CustomTestCase {
    override func tearDown() async throws {
        try? await Setting.update(key: .isRegistrationOpened, value: .boolean(true))
        try? await Setting.update(key: .isRegistrationByApprovalOpened, value: .boolean(false))
        try? await Setting.update(key: .isRegistrationByInvitationsOpened, value: .boolean(false))
    }

    func testUserAccountShouldBeCreatedForValidUserData() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "annasmith",
                                              email: "annasmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Anna Smith",
                                              securityToken: "123")

        // Act.
        let createdUserDto = try SharedApplication.application()
            .getResponse(to: "/register", method: .POST, data: registerUserDto, decodeTo: UserDto.self)

        // Assert.
        XCTAssert(createdUserDto.id != nil, "User wasn't created.")
    }

    func testCreatedStatusCodeShouldBeReturnedAfterCreatingNewUser() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "martinsmith",
                                              email: "martinsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Martin Smith",
                                              securityToken: "123")

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/register", method: .POST, body: registerUserDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.created, "Response http status code should be created (201).")
    }

    func testHeaderLocationShouldBeReturnedAfterCreatingNewUser() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "victoriasmith",
                                              email: "victoriasmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Victoria Smith",
                                              securityToken: "123")

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/register", method: .POST, body: registerUserDto)

        // Assert.
        let location = response.headers.first(name: .location)
        let user = try response.content.decode(UserDto.self)
        XCTAssertEqual(location, "/users/@\(user.userName)", "Location header should contains created username.")
    }

    func testCorrectUserDataShouldBeReturnedAfterCreatingNewUser() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "dansmith",
                                              email: "dansmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Dan Smith",
                                              bio: "User biography",
                                              securityToken: "123")

        // Act.
        let createdUserDto = try SharedApplication.application().getResponse(to: "/register", method: .POST, data: registerUserDto, decodeTo: UserDto.self)

        // Assert.
        XCTAssertEqual(createdUserDto.userName, "dansmith", "User name is not correcrt.")
        XCTAssertEqual(createdUserDto.email, "dansmith@testemail.com", "Email is not correct.")
        XCTAssertEqual(createdUserDto.name, "Dan Smith", "Name is not correct.")
        XCTAssertEqual(createdUserDto.bio, "User biography", "User biography is not correct")
    }

    func testNewUserShouldBeAssignedToDefaultRoles() async throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "briansmith",
                                              email: "briansmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Brian Smith",
                                              securityToken: "123")

        // Act.
        _ = try SharedApplication.application().getResponse(to: "/register", method: .POST, data: registerUserDto, decodeTo: UserDto.self)

        // Assert.
        let user = try await User.get(userName: "briansmith")
        XCTAssertEqual(user.roles[0].code, "member", "Default user roles should be added to user")
    }

    func testNewUserShouldHaveGeneratedCryptographicKeys() async throws {
        
        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "naomirock",
                                              email: "naomirock@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Naomi Rock",
                                              securityToken: "123")

        // Act.
        _ = try SharedApplication.application().getResponse(to: "/register", method: .POST, data: registerUserDto, decodeTo: UserDto.self)

        // Assert.
        let user = try await User.get(userName: "naomirock")
        XCTAssertTrue(user.privateKey!.starts(with: "-----BEGIN RSA PRIVATE KEY-----"), "Private key has not been generated")
        XCTAssertTrue(user.publicKey!.starts(with: "-----BEGIN PUBLIC KEY-----"), "Public key has not been generated")
    }
    
    func testUserShouldNotBeCreatedIfUserWithTheSameEmailExists() async throws {

        // Arrange.
        _ = try await User.create(userName: "jurgensmith",
                            email: "jurgensmith@testemail.com",
                            name: "Jurgen Smith")

        let registerUserDto = RegisterUserDto(userName: "notexists",
                                              email: "jurgensmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Jurgen Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "emailIsAlreadyConnected", "Error code should be equal 'emailIsAlreadyConnected'.")
    }

    func testUserShouldNotBeCreatedIfUserWithTheSameUserNameExists() async throws {

        // Arrange.
        _ = try await User.create(userName: "teddysmith")
        let registerUserDto = RegisterUserDto(userName: "teddysmith",
                                              email: "teddysmith-notexists@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Samantha Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "userNameIsAlreadyTaken", "Error code should be equal 'userNameIsAlreadyTaken'.")
    }

    func testUserShouldNotBeCreatedIfUserNameWasNotSpecified() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "",
                                              email: "gregsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("userName"), "is less than minimum of 1 character(s)")
    }

    func testUserShouldNotBeCreatedIfUserNameWasTooLong() throws {
    
        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "123456789012345678901234567890123456789012345678901",
                                              email: "gregsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("userName"), "is greater than maximum of 50 character(s)")
    }

    func testUserShouldNotBeCreatedIfEmailWasNotSpecified() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("email"), "is not a valid email address")
    }

    func testUserShouldNotBeCreatedIfEmailHasWrongFormat() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmithtestemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("email"), "is not a valid email address")
    }

    func testUserShouldNotBeCreatedIfPasswordWasNotSpecified() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("password"), "is less than minimum of 8 character(s) and is not a valid password")
    }

    func testUserShouldNotBeCreatedIfPasswordIsTooShort() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "1234567",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("password"), "is less than minimum of 8 character(s) and is not a valid password")
    }

    func testUserShouldNotBeCreatedIfPasswordIsTooLong() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "123456789012345678901234567890123",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Greg Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("password"), "is greater than maximum of 32 character(s) and is not a valid password")
    }

    func testUserShouldNotBeCreatedIfNameIsTooLong() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("name"), "is not null and is greater than maximum of 100 character(s)")
    }

    func testUserShouldNotBeCreatedIfBioIsTooLong() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Greg Smith",
                                              bio: "12345678901234567890123456789012345678901234567890" +
                                                   "12345678901234567890123456789012345678901234567890" +
                                                   "12345678901234567890123456789012345678901234567890" +
                                                   "12345678901234567890123456789012345678901234567890" +
                                                   "12345678901234567890123456789012345678901234567890" +
                                                   "12345678901234567890123456789012345678901234567890" +
                                                   "12345678901234567890123456789012345678901234567890" +
                                                   "12345678901234567890123456789012345678901234567890" +
                                                   "12345678901234567890123456789012345678901234567890" +
                                                   "123456789012345678901234567890123456789012345678901",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("bio"), "is not null and is greater than maximum of 500 character(s)")
    }

    func testUserShouldNotBeCreatedIfSecurityTokenWasNotSpecified() throws {

        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                              email: "gregsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Greg Smith",
                                              securityToken: nil)

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("securityToken"), "is required")
    }
    
    func testUserShouldNotBeCreatedIfRegistrationIsDisabled() async throws {
        // Arrange.
        try await Setting.update(key: .isRegistrationOpened, value: .boolean(false))
        try await Setting.update(key: .isRegistrationByApprovalOpened, value: .boolean(false))
        try await Setting.update(key: .isRegistrationByInvitationsOpened, value: .boolean(false))

        let registerUserDto = RegisterUserDto(userName: "brushsmith",
                                              email: "brushsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Brush Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "registrationIsDisabled", "Error code should be equal 'registrationIsDisabled'.")
    }
    
    func testUserShouldNotBeCreatedWhenUserNotAcceptAgreement() async throws {
        // Arrange.
        let registerUserDto = RegisterUserDto(userName: "mariuszsmith",
                                              email: "mariuszsmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: false,
                                              name: "Mariusz Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "userHaveToAcceptAgreeent", "Error code should be equal 'userHaveToAcceptAgreeent'.")
    }
    
    func testUserShouldBeCreatedIfRegistrationByApprovalIsEnabledAndReasonIsSpecified() async throws {
        // Arrange.
        try await Setting.update(key: .isRegistrationOpened, value: .boolean(false))
        try await Setting.update(key: .isRegistrationByApprovalOpened, value: .boolean(true))
        try await Setting.update(key: .isRegistrationByInvitationsOpened, value: .boolean(false))

        let registerUserDto = RegisterUserDto(userName: "henrysmith",
                                              email: "henrysmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Henry Smith",
                                              securityToken: "123",
                                              reason: "This is a registration reason")

        // Act.
        let createdUserDto = try SharedApplication.application()
            .getResponse(to: "/register", method: .POST, data: registerUserDto, decodeTo: UserDto.self)

        // Assert.
        XCTAssert(createdUserDto.id != nil, "User wasn't created.")
    }
    
    func testUserShouldNotBeCreatedIfRegistrationByApprovalIsEnabledAndReasonIsNotSpecified() async throws {
        // Arrange.
        try await Setting.update(key: .isRegistrationOpened, value: .boolean(false))
        try await Setting.update(key: .isRegistrationByApprovalOpened, value: .boolean(true))
        try await Setting.update(key: .isRegistrationByInvitationsOpened, value: .boolean(false))

        let registerUserDto = RegisterUserDto(userName: "bensmith",
                                              email: "bensmith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Ben Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "registrationIsDisabled", "Error code should be equal 'registrationIsDisabled'.")
    }
    
    func testUserShouldBeCreatedIfRegistrationByInvitationIsEnabledAndTokenIsSpecified() async throws {
        // Arrange.
        try await Setting.update(key: .isRegistrationOpened, value: .boolean(false))
        try await Setting.update(key: .isRegistrationByApprovalOpened, value: .boolean(false))
        try await Setting.update(key: .isRegistrationByInvitationsOpened, value: .boolean(true))
        
        let user = try await User.create(userName: "norbismith")
        let invitation = try await Invitation.create(userId: user.requireID())

        let registerUserDto = RegisterUserDto(userName: "waldismith",
                                              email: "waldismith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Waldi Smith",
                                              securityToken: "123",
                                              inviteToken: invitation.code)

        // Act.
        let createdUserDto = try SharedApplication.application()
            .getResponse(to: "/register", method: .POST, data: registerUserDto, decodeTo: UserDto.self)

        // Assert.
        XCTAssert(createdUserDto.id != nil, "User wasn't created.")
    }
    
    func testUserShouldNotBeCreatedIfRegistrationByInvitationIsEnabledAndTokenIsNotSpecified() async throws {
        // Arrange.
        try await Setting.update(key: .isRegistrationOpened, value: .boolean(false))
        try await Setting.update(key: .isRegistrationByApprovalOpened, value: .boolean(false))
        try await Setting.update(key: .isRegistrationByInvitationsOpened, value: .boolean(true))

        let registerUserDto = RegisterUserDto(userName: "waldismith",
                                              email: "waldismith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Waldi Smith",
                                              securityToken: "123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "registrationIsDisabled", "Error code should be equal 'registrationIsDisabled'.")
    }
    
    func testUserShouldNotBeCreatedIfRegistrationByInvitationIsEnabledAndTokenIsWrong() async throws {
        // Arrange.
        try await Setting.update(key: .isRegistrationOpened, value: .boolean(false))
        try await Setting.update(key: .isRegistrationByApprovalOpened, value: .boolean(false))
        try await Setting.update(key: .isRegistrationByInvitationsOpened, value: .boolean(true))

        let user = try await User.create(userName: "kikosmith")
        
        let registerUserDto = RegisterUserDto(userName: "waldismith",
                                              email: "waldismith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Waldi Smith",
                                              securityToken: "123",
                                              inviteToken: "234234234")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "invitationTokenIsInvalid", "Error code should be equal 'invitationTokenIsInvalid'.")
    }
    
    func testUserShouldNotBeCreatedIfRegistrationByInvitationIsEnabledAndTokenHasBeenUsed() async throws {
        // Arrange.
        try await Setting.update(key: .isRegistrationOpened, value: .boolean(false))
        try await Setting.update(key: .isRegistrationByApprovalOpened, value: .boolean(false))
        try await Setting.update(key: .isRegistrationByInvitationsOpened, value: .boolean(true))

        let user = try await User.create(userName: "ulasmith")
        let invitation = try await Invitation.create(userId: user.requireID())
        try await invitation.set(invitedId: user.requireID())
        
        let registerUserDto = RegisterUserDto(userName: "waldismith",
                                              email: "waldismith@testemail.com",
                                              password: "p@ssword",
                                              redirectBaseUrl: "http://localhost:4200",
                                              agreement: true,
                                              name: "Waldi Smith",
                                              securityToken: "123",
                                              inviteToken: invitation.code)

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/register",
            method: .POST,
            data: registerUserDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "invitationTokenHasBeenUsed", "Error code should be equal 'invitationTokenHasBeenUsed'.")
    }
}
