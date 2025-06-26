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
    
    @Suite("Register (POST /register)", .serialized, .tags(.register))
    struct RegisterActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("User account should be created for valid user data")
        func userAccountShouldBeCreatedForValidUserData() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "annasmith",
                                                  email: "annasmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Anna Smith",
                                                  securityToken: "123")
            
            // Act.
            let createdUserDto = try await application.getResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto,
                decodeTo: UserDto.self)
            
            // Assert.
            #expect(createdUserDto.id != nil, "User wasn't created.")
            
            let statusesFromApi = try await application.getResponse(
                as: .user(userName: "annasmith", password: "p@ssword"),
                to: "/timelines/home?limit=2",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            #expect(statusesFromApi.data.count == 0, "Statuses list should be returned.")
        }
        
        @Test("Created status code should be returned after creating new user")
        func createdStatusCodeShouldBeReturnedAfterCreatingNewUser() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "martinsmith",
                                                  email: "martinsmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Martin Smith",
                                                  securityToken: "123")
            
            // Act.
            let response = try await application.sendRequest(to: "/register", method: .POST, body: registerUserDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.created, "Response http status code should be created (201).")
        }
        
        @Test("Header location should be returned after creating new user")
        func headerLocationShouldBeReturnedAfterCreatingNewUser() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "victoriasmith",
                                                  email: "victoriasmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Victoria Smith",
                                                  securityToken: "123")
            
            // Act.
            let response = try await application.sendRequest(to: "/register", method: .POST, body: registerUserDto)
            
            // Assert.
            let location = response.headers.first(name: .location)
            let user = try response.content.decode(UserDto.self)
            #expect(location == "/users/@\(user.userName)", "Location header should contains created username.")
        }
        
        @Test("Correct user data should be returned after creating new user")
        func correctUserDataShouldBeReturnedAfterCreatingNewUser() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "dansmith",
                                                  email: "dansmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Dan Smith",
                                                  securityToken: "123")
            
            // Act.
            let createdUserDto = try await application.getResponse(to: "/register", method: .POST, data: registerUserDto, decodeTo: UserDto.self)
            
            // Assert.
            #expect(createdUserDto.userName == "dansmith", "User name is not correcrt.")
            #expect(createdUserDto.email == "dansmith@testemail.com", "Email is not correct.")
            #expect(createdUserDto.name == "Dan Smith", "Name is not correct.")
            #expect(createdUserDto.url == "http://localhost:8080/@dansmith", "Name is not correct.")
        }
        
        @Test("New user should be assigned to default roles")
        func newUserShouldBeAssignedToDefaultRoles() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "briansmith",
                                                  email: "briansmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Brian Smith",
                                                  securityToken: "123")
            
            // Act.
            _ = try await application.getResponse(to: "/register", method: .POST, data: registerUserDto, decodeTo: UserDto.self)
            
            // Assert.
            let user = try await application.getUser(userName: "briansmith")
            #expect(user.roles[0].code == Role.member, "Default user roles should be added to user")
        }
        
        @Test("New user should have generated cryptographic keys")
        func newUserShouldHaveGeneratedCryptographicKeys() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "naomirock",
                                                  email: "naomirock@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Naomi Rock",
                                                  securityToken: "123")
            
            // Act.
            _ = try await application.getResponse(to: "/register", method: .POST, data: registerUserDto, decodeTo: UserDto.self)
            
            // Assert.
            let user = try await application.getUser(userName: "naomirock")
            #expect(user.privateKey!.starts(with: "-----BEGIN RSA PRIVATE KEY-----"), "Private key has not been generated")
            #expect(user.publicKey!.starts(with: "-----BEGIN PUBLIC KEY-----"), "Public key has not been generated")
        }
        
        @Test("User should not be created if user with the same email exists")
        func userShouldNotBeCreatedIfUserWithTheSameEmailExists() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "jurgensmith",
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
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "emailIsAlreadyConnected", "Error code should be equal 'emailIsAlreadyConnected'.")
        }
        
        @Test("User should not be created if user With the same userName exists")
        func userShouldNotBeCreatedIfUserWithTheSameUserNameExists() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "teddysmith")
            let registerUserDto = RegisterUserDto(userName: "teddysmith",
                                                  email: "teddysmith-notexists@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Samantha Smith",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "userNameIsAlreadyTaken", "Error code should be equal 'userNameIsAlreadyTaken'.")
        }
        
        @Test("User should not be created if userName was not specified")
        func userShouldNotBeCreatedIfUserNameWasNotSpecified() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "",
                                                  email: "gregsmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Greg Smith",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("userName") == "is less than minimum of 1 character(s)")
        }
        
        @Test("User should not be created if userName was too long")
        func userShouldNotBeCreatedIfUserNameWasTooLong() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "123456789012345678901234567890123456789012345678901",
                                                  email: "gregsmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Greg Smith",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("userName") == "is greater than maximum of 50 character(s)")
        }
        
        @Test("User should not be created if email was not specified")
        func userShouldNotBeCreatedIfEmailWasNotSpecified() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                                  email: "",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Greg Smith",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("email") == "is not a valid email address")
        }
        
        @Test("User should not be created if email has wrong format")
        func userShouldNotBeCreatedIfEmailHasWrongFormat() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                                  email: "gregsmithtestemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Greg Smith",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("email") == "is not a valid email address")
        }
        
        @Test("User should not be created if password was not specified")
        func userShouldNotBeCreatedIfPasswordWasNotSpecified() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                                  email: "gregsmith@testemail.com",
                                                  password: "",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Greg Smith",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("password") == "is less than minimum of 8 character(s) and is not a valid password")
        }
        
        @Test("User should not be created if password is too short")
        func userShouldNotBeCreatedIfPasswordIsTooShort() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                                  email: "gregsmith@testemail.com",
                                                  password: "1234567",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Greg Smith",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("password") == "is less than minimum of 8 character(s) and is not a valid password")
        }
        
        @Test("User should not be created if password is too long")
        func userShouldNotBeCreatedIfPasswordIsTooLong() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                                  email: "gregsmith@testemail.com",
                                                  password: "123456789012345678901234567890123",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Greg Smith",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("password") == "is greater than maximum of 32 character(s) and is not a valid password")
        }
        
        @Test("User should not be created if name is too long")
        func userShouldNotBeCreatedIfNameIsTooLong() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                                  email: "gregsmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("name") == "is not null and is greater than maximum of 100 character(s)")
        }
        
        @Test("User should not be created if security token was not specified")
        func userShouldNotBeCreatedIfSecurityTokenWasNotSpecified() async throws {
            
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "gregsmith",
                                                  email: "gregsmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Greg Smith",
                                                  securityToken: nil)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("securityToken") == "is required")
        }
        
        @Test("User should not be created if registration is disabled")
        func userShouldNotBeCreatedIfRegistrationIsDisabled() async throws {
            // Arrange.
            try await application.updateSetting(key: .isRegistrationOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByApprovalOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByInvitationsOpened, value: .boolean(false))
            
            let registerUserDto = RegisterUserDto(userName: "brushsmith",
                                                  email: "brushsmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Brush Smith",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "registrationIsDisabled", "Error code should be equal 'registrationIsDisabled'.")
        }
        
        @Test("User should not be created when user not accept agreement")
        func userShouldNotBeCreatedWhenUserNotAcceptAgreement() async throws {
            // Arrange.
            let registerUserDto = RegisterUserDto(userName: "mariuszsmith",
                                                  email: "mariuszsmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: false,
                                                  name: "Mariusz Smith",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "userHaveToAcceptAgreement", "Error code should be equal 'userHaveToAcceptAgreement'.")
        }
        
        @Test("User should be created if registration by approval is enabled and reason is specified")
        func userShouldBeCreatedIfRegistrationByApprovalIsEnabledAndReasonIsSpecified() async throws {
            // Arrange.
            try await application.updateSetting(key: .isRegistrationOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByApprovalOpened, value: .boolean(true))
            try await application.updateSetting(key: .isRegistrationByInvitationsOpened, value: .boolean(false))
            
            let registerUserDto = RegisterUserDto(userName: "henrysmith",
                                                  email: "henrysmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Henry Smith",
                                                  securityToken: "123",
                                                  reason: "This is a registration reason")
            
            // Act.
            let createdUserDto = try await application
                .getResponse(to: "/register", method: .POST, data: registerUserDto, decodeTo: UserDto.self)
            
            // Assert.
            #expect(createdUserDto.id != nil, "User wasn't created.")
        }
        
        @Test("User should not be created if registration by approval is enabled and reason is not specified")
        func userShouldNotBeCreatedIfRegistrationByApprovalIsEnabledAndReasonIsNotSpecified() async throws {
            // Arrange.
            try await application.updateSetting(key: .isRegistrationOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByApprovalOpened, value: .boolean(true))
            try await application.updateSetting(key: .isRegistrationByInvitationsOpened, value: .boolean(false))
            
            let registerUserDto = RegisterUserDto(userName: "bensmith",
                                                  email: "bensmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Ben Smith",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "registrationIsDisabled", "Error code should be equal 'registrationIsDisabled'.")
        }
        
        @Test("User should be created if registration by invitation is enabled and token is specified")
        func userShouldBeCreatedIfRegistrationByInvitationIsEnabledAndTokenIsSpecified() async throws {
            // Arrange.
            try await application.updateSetting(key: .isRegistrationOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByApprovalOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByInvitationsOpened, value: .boolean(true))
            
            let user = try await application.createUser(userName: "norbismith")
            let invitation = try await application.createInvitation(userId: user.requireID())
            
            let registerUserDto = RegisterUserDto(userName: "waldismith",
                                                  email: "waldismith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Waldi Smith",
                                                  securityToken: "123",
                                                  inviteToken: invitation.code)
            
            // Act.
            let createdUserDto = try await application.getResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto,
                decodeTo: UserDto.self)
            
            // Assert.
            #expect(createdUserDto.id != nil, "User wasn't created.")
            
            let statusesFromApi = try await application.getResponse(
                as: .user(userName: "waldismith", password: "p@ssword"),
                to: "/timelines/home?limit=2",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            #expect(statusesFromApi.data.count == 0, "Statuses list should be returned.")
        }
        
        @Test("User should not be created if registration by invitation is enable aAnd token is not specified")
        func userShouldNotBeCreatedIfRegistrationByInvitationIsEnabledAndTokenIsNotSpecified() async throws {
            // Arrange.
            try await application.updateSetting(key: .isRegistrationOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByApprovalOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByInvitationsOpened, value: .boolean(true))
            
            let registerUserDto = RegisterUserDto(userName: "waldismith",
                                                  email: "waldismith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Waldi Smith",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "registrationIsDisabled", "Error code should be equal 'registrationIsDisabled'.")
        }
        
        @Test("User should not be created if registration by invitation is enabled and token is wrong")
        func userShouldNotBeCreatedIfRegistrationByInvitationIsEnabledAndTokenIsWrong() async throws {
            // Arrange.
            try await application.updateSetting(key: .isRegistrationOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByApprovalOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByInvitationsOpened, value: .boolean(true))
            
            _ = try await application.createUser(userName: "kikosmith")
            
            let registerUserDto = RegisterUserDto(userName: "waldismith",
                                                  email: "waldismith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Waldi Smith",
                                                  securityToken: "123",
                                                  inviteToken: "234234234")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "invitationTokenIsInvalid", "Error code should be equal 'invitationTokenIsInvalid'.")
        }
        
        @Test("User should not be created if registration by invitation is enabled and token has been used")
        func userShouldNotBeCreatedIfRegistrationByInvitationIsEnabledAndTokenHasBeenUsed() async throws {
            // Arrange.
            try await application.updateSetting(key: .isRegistrationOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByApprovalOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByInvitationsOpened, value: .boolean(true))
            
            let user = try await application.createUser(userName: "ulasmith")
            let invitation = try await application.createInvitation(userId: user.requireID())
            try await application.set(invitation: invitation, invitedId: user.requireID())
            
            let registerUserDto = RegisterUserDto(userName: "waldismith",
                                                  email: "waldismith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Waldi Smith",
                                                  securityToken: "123",
                                                  inviteToken: invitation.code)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "invitationTokenHasBeenUsed", "Error code should be equal 'invitationTokenHasBeenUsed'.")
        }
        
        @Test("User should not be created when registering with disposable email")
        func userShouldNotBeCreatedWhenRegisteringWithDisposableEmail() async throws {
            
            // Arrange.
            try? await application.updateSetting(key: .isRegistrationOpened, value: .boolean(true))
            try? await application.updateSetting(key: .isRegistrationByApprovalOpened, value: .boolean(false))
            try? await application.updateSetting(key: .isRegistrationByInvitationsOpened, value: .boolean(false))
            _ = try await application.createDisposableEmail(domain: "10minutes.net")
            
            let registerUserDto = RegisterUserDto(userName: "robingobis",
                                                  email: "robingobis@10minutes.net",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Robin Gobis",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "disposableEmailCannotBeUsed", "Error code should be equal 'disposableEmailCannotBeUsed'.")
        }
        
        @Test("User should not be created if registration is opened and captcha is enabled and not solved")
        func userShouldNotBeCreatedIfRegistrationIsOpenedAndCaptchaIsEnabledAndNotSolved() async throws {
            // Arrange.
            try await application.updateSetting(key: .isRegistrationOpened, value: .boolean(true))
            try await application.updateSetting(key: .isRegistrationByApprovalOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByInvitationsOpened, value: .boolean(false))
            try await application.updateSetting(key: .isQuickCaptchaEnabled, value: .boolean(true))
            
            let registerUserDto = RegisterUserDto(userName: "brushsmith",
                                                  email: "brushsmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Brush Smith",
                                                  securityToken: "123")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "securityTokenIsInvalid", "Error code should be equal 'securityTokenIsInvalid'.")
        }
        
        @Test("User should be created if registration is and opened captcha is enabled and solved")
        func userShouldBeCreatedIfRegistrationIsOpenedAndCaptchaIsEnabledAndSolved() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .isRegistrationOpened, value: .boolean(true))
            try await application.updateSetting(key: .isRegistrationByApprovalOpened, value: .boolean(false))
            try await application.updateSetting(key: .isRegistrationByInvitationsOpened, value: .boolean(false))
            try await application.updateSetting(key: .isQuickCaptchaEnabled, value: .boolean(true))
            
            let key = String.createRandomString(length: 16)
            let quickCaptcha = try await application.createQuickCaptcha(key: key, text: "abcdef")
            let registerUserDto = RegisterUserDto(userName: "kirksmith",
                                                  email: "kirksmith@testemail.com",
                                                  password: "p@ssword",
                                                  redirectBaseUrl: "http://localhost:4200",
                                                  agreement: true,
                                                  name: "Anna Smith",
                                                  securityToken: "\(quickCaptcha.key)/\(quickCaptcha.text)")
            
            // Act.
            let createdUserDto = try await application.getResponse(
                to: "/register",
                method: .POST,
                data: registerUserDto,
                decodeTo: UserDto.self)
            
            // Assert.
            #expect(createdUserDto.id != nil, "User wasn't created.")
        }
    }
}
