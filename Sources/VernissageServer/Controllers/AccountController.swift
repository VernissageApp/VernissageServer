//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension AccountController: RouteCollection {

    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("account")

    func boot(routes: RoutesBuilder) throws {
        let accountGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(AccountController.uri)

        accountGroup
            .grouped(LoginHandlerMiddleware())
            .post("login", use: login)
        
        accountGroup
            .grouped(EventHandlerMiddleware(.accountConfirm))
            .grouped("email")
            .post("confirm", use: confirm)
        
        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.accountConfirm))
            .grouped("email")
            .post("resend", use: resend)
        
        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.accountChangeEmail))
            .put("email", use: changeEmail)
        
        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.accountChangePassword, storeRequest: false))
            .put("password", use: changePassword)

        accountGroup
            .grouped(EventHandlerMiddleware(.accountForgotToken))
            .grouped("forgot")
            .post("token", use: forgotPasswordToken)
        
        accountGroup
            .grouped(EventHandlerMiddleware(.accountForgotConfirm, storeRequest: false))
            .grouped("forgot")
            .post("confirm", use: forgotPasswordConfirm)
        
        accountGroup
            .grouped(EventHandlerMiddleware(.accountRefresh))
            .post("refresh-token", use: refresh)
        
        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.accountRevoke))
            .delete("refresh-token", ":username", use: revoke)
    }
}

/// Controller for generic account operation.
///
/// Actions in the controller are designed to handle basic operations related to a user's account in the system,
/// such as logging in, changing email, password, etc.
///
/// > Important: Base controller URL: `/api/v1/account`.
final class AccountController {

    /// Sign-in user via login (usernane or email) and password.
    ///
    /// With this endpoint, users can log in to the system using their username or their email and password.
    /// Two tokens are returned in response. The `accessToken` must be sent in every request that requires confirmation
    /// of the user's identity. The `refreshToken` **MUST** be sent only to replace the `accessToken` before it expires.
    /// The default expiration time for `accessToken` is 1 hour. The expiration time of `refreshToken` is 30 days.
    ///
    /// > Important: Endpoint URL: `/api/v1/account/login`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/login" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "userNameOrEmail": "johndoe",
    ///     "password": "P@ssword1!"
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "accessToken": "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJyb2xlcyI6W10sInVzZXJOYW1lIjoibmlja2Z...",
    ///     "refreshToken": "8v4JbrTeboHsD5T24WdhkkHgVx3UQ2F2FQaZd3sT0"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint ``LoginRequestDto``.
    ///
    /// - Returns: User's access tokens.
    ///
    /// - Throws: `LoginError.invalidLoginCredentials` if given user name or password are invalid.
    /// - Throws: `LoginError.userAccountIsBlocked` if user account is blocked. User cannot login to the system right now.
    /// - Throws: `LoginError.userAccountIsNotApproved` if user account is not aprroved yet. User cannot login to the system right now.
    /// - Throws: `LoginError.saltCorrupted` if password has been corrupted. Please contact with portal administrator.
    func login(request: Request) async throws -> AccessTokenDto {
        let loginRequestDto = try request.content.decode(LoginRequestDto.self)
        let usersService = request.application.services.usersService

        let user = try await usersService.login(on: request,
                                                userNameOrEmail: loginRequestDto.userNameOrEmail,
                                                password: loginRequestDto.password)

        let tokensService = request.application.services.tokensService
        let accessToken = try await tokensService.createAccessTokens(on: request, forUser: user)

        return accessToken
    }
    
    /// Changing user mail.
    ///
    /// With this endpoint, the user is able to change his email in the system. Once the request is sent, the server will send a message
    /// to the specified email, which will include a link to confirm receipt of the message. Only after clicking on the link is the new email confirmed.
    ///
    /// > Important: Endpoint URL: `/api/v1/account/email`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/email" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "email": "new@email.com",
    ///     "redirectBaseUrl": "https://example.com"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint ``ChangeEmailDto``.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `Validation.validationError` if validation errors occurs.
    /// - Throws: `RegisterError.emailIsAlreadyConnected` if email is already connected with other account.
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    func changeEmail(request: Request) async throws -> HTTPResponseStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let user = try await User.find(authorizationPayloadId, on: request.db) else {
            throw Abort(.notFound)
        }

        let changeEmailDto = try request.content.decode(ChangeEmailDto.self)
        try ChangeEmailDto.validate(content: request)

        let usersService = request.application.services.usersService
        try await usersService.validateEmail(on: request, email: changeEmailDto.email)
        
        // Change email in database.
        try await usersService.changeEmail(
            on: request,
            userId: authorizationPayloadId,
            email: changeEmailDto.email
        )
        
        // Send email with email confirmation message.
        try await self.sendConfirmEmail(on: request, user: user, redirectBaseUrl: changeEmailDto.redirectBaseUrl)

        return HTTPStatus.ok
    }
    
    /// New account (email) confirmation.
    ///
    /// Endpoint should be used for email verification. During creating account special email is sending.
    /// In that email there is a link to your website (with id and confirmationGuid as query parameters).
    /// You have to create page which will read that parameters and it should send request to following endpoint.
    ///
    /// > Important: Endpoint URL: `/api/v1/account/email/confirm`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/email/confirm" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "id": "7243149752689283073",
    ///     "confirmationGuid": "fe4547e0-513d-40fb-8a1f-35c9e4beb8e9"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint ``ConfirmEmailRequestDto``.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `ConfirmEmailError.invalidIdOrToken` if invalid user Id or token. Email cannot be approved.
    func confirm(request: Request) async throws -> HTTPResponseStatus {
        let confirmEmailRequestDto = try request.content.decode(ConfirmEmailRequestDto.self)
        let usersService = request.application.services.usersService

        guard let userId = confirmEmailRequestDto.id.toId() else {
            throw ConfirmEmailError.invalidIdOrToken
        }
        
        try await usersService.confirmEmail(on: request,
                                            userId: userId,
                                            confirmationGuid: confirmEmailRequestDto.confirmationGuid)

        return HTTPStatus.ok
    }

    /// Resend confirmation email to user email box.
    ///
    /// Endpoint should be used for resending email for email verification. User have to be signed in into the
    /// system and `Bearer` token have to be attached to the request.
    /// 
    /// > Important: Endpoint URL: `/api/v1/account/email/resend`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/email/resend" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "redirectBaseUrl": "https://example.com"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint ``ResendEmailConfirmationDto``.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `AccountError.emailIsAlreadyConfirmed` if email is already confirmed.
    func resend(request: Request) async throws -> HTTPResponseStatus {
        let resendEmailConfirmationDto = try request.content.decode(ResendEmailConfirmationDto.self)

        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        guard let user = try await User.find(authorizationPayloadId, on: request.db) else {
            throw Abort(.notFound)
        }
        
        guard user.emailWasConfirmed == false else {
            throw AccountError.emailIsAlreadyConfirmed
        }
        
        let emailsService = request.application.services.emailsService
        try await emailsService.dispatchConfirmAccountEmail(on: request,
                                                            user: user,
                                                            redirectBaseUrl: resendEmailConfirmationDto.redirectBaseUrl)

        return HTTPStatus.ok
    }
        
    /// Change password.
    ///
    /// Changing user password. In the request old and new passwords have to be specified and user have to be signed in into the system.
    ///
    /// > Important: Endpoint URL: `/api/v1/account/email/password`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/password" \
    /// -X PUT \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    /// 
    /// ```json
    /// {
    ///     "currentPassword": "P@ssword1!"
    ///     "newPassword": "NewPassword1!"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint ``ChangePasswordRequestDto``.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `Validation.validationError` if validation errors occurs.
    /// - Throws: `ChangePasswordError.invalidOldPassword` if given old password is invalid
    /// - Throws: `ChangePasswordError.userAccountIsBlocked` if user account is blocked. User cannot login to the system right now.
    /// - Throws: `ChangePasswordError.userNotFound` if signed user was not found in the database.
    /// - Throws: `ChangePasswordError.emailNotConfirmed` if user email is not confirmed. User have to confirm his email first.
    /// - Throws: `ChangePasswordError.saltCorrupted` if password has been corrupted. Please contact with portal administrator.
    func changePassword(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        let changePasswordRequestDto = try request.content.decode(ChangePasswordRequestDto.self)
        try ChangePasswordRequestDto.validate(content: request)

        let usersService = request.application.services.usersService

        try await usersService.changePassword(
            on: request,
            userId: authorizationPayloadId,
            currentPassword: changePasswordRequestDto.currentPassword,
            newPassword: changePasswordRequestDto.newPassword
        )

        return HTTPStatus.ok
    }

    /// Sending email with token for authenticate changing password request.
    ///
    /// Sending email with token for authenticate changing password request. Url from email will redirect to client
    /// application (with token in query string). Client application have to ask for new password and send new
    /// password and token from query string.
    ///
    /// > Important: Endpoint URL: `/api/v1/account/forgot/token`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/forgot/token" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "email": "johndoe@example.com",
    ///     "redirectBaseUrl": "https://example.com"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint ``ForgotPasswordRequestDto``.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `Validation.validationError` if validation errors occurs.
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `ForgotPasswordError.userAccountIsBlocked` if user account is blocked. You cannot change password right now.
    func forgotPasswordToken(request: Request) async throws -> HTTPResponseStatus {
        let forgotPasswordRequestDto = try request.content.decode(ForgotPasswordRequestDto.self)
        
        let usersService = request.application.services.usersService
        let emailsService = request.application.services.emailsService

        let user = try await usersService.forgotPassword(on: request, email: forgotPasswordRequestDto.email)
        
        try await emailsService.dispatchForgotPasswordEmail(on: request,
                                                            user: user,
                                                            redirectBaseUrl: forgotPasswordRequestDto.redirectBaseUrl)

        return HTTPStatus.ok
    }

    /// Change password based on token from email.
    ///
    /// With this endpoint, it is possible to send a new password to the system. It is possible to change the password
    /// because the GUID that was previously sent to the email provided by the user is sent along with the password.
    ///
    /// > Important: Endpoint URL: `/api/v1/account/forgot/confirm`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/forgot/confirm" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "forgotPasswordGuid": "f0a5d44f-9f91-4514-b045-71cd096a84f2",
    ///     "password": "newP@ssword1!"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint ``ForgotPasswordConfirmationRequestDto``.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `Validation.validationError` if validation errors occurs.
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `ForgotPasswordError.emailIsEmpty` if user email is empty. Cannot send email with token.
    /// - Throws: `ForgotPasswordError.userAccountIsBlocked` if user account is blocked. You cannot change password right now.
    /// - Throws: `ForgotPasswordError.tokenExpired` if token which allows to change password expired. User have to repeat forgot password process.
    /// - Throws: `ForgotPasswordError.tokenNotGenerated` if torgot password token wasn't generated. It's really strange.
    /// - Throws: `ForgotPasswordError.passwordNotHashed` if password was not hashed successfully.
    /// - Throws: `ForgotPasswordError.saltCorrupted` if password has been corrupted. Please contact with portal administrator.
    func forgotPasswordConfirm(request: Request) async throws -> HTTPResponseStatus {
        let confirmationDto = try request.content.decode(ForgotPasswordConfirmationRequestDto.self)
        try ForgotPasswordConfirmationRequestDto.validate(content: request)

        let usersService = request.application.services.usersService
        try await usersService.confirmForgotPassword(
            on: request,
            forgotPasswordGuid: confirmationDto.forgotPasswordGuid,
            password: confirmationDto.password
        )

        return HTTPStatus.ok
    }
    
    /// Refresh `accessToken` token by sending `refreshToken`.
    ///
    /// Endpoint will regenerate new `accessToken` based on `refreshToken` which has been generated during the login process.
    /// This is the only endpoint to which the `refreshToken` should be sent, only when the `accessToken` expires (or a moment before it expires).
    ///
    /// > Important: Endpoint URL: `/api/v1/account/refresh-token`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/refresh-token" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "refreshToken": "8v4JbrTeboHsD5T24WdhkkHgVx3UQ2F2FQaZd3sT0"
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "accessToken": "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJyb2xlcyI6W10sInVzZXJOYW1lIjoibmlja2Z...",
    ///     "refreshToken": "8v4JbrTeboHsD5T24WdhkkHgVx3UQ2F2FQaZd3sT0"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint ``RefreshTokenDto``.
    ///
    /// - Returns: User's access tokens.
    ///
    /// - Throws: `EntityNotFoundError.refreshTokenNotFound` if refresh token not exists.
    /// - Throws: `RefreshTokenError.refreshTokenRevoked` if refresh token was revoked.
    /// - Throws: `RefreshTokenError.refreshTokenExpired` if refresh token was expired.
    /// - Throws: `LoginError.userAccountIsBlocked` if user account is blocked.
    func refresh(request: Request) async throws -> AccessTokenDto {
        let refreshTokenDto = try request.content.decode(RefreshTokenDto.self)
        let tokensService = request.application.services.tokensService

        let refreshToken = try await tokensService.validateRefreshToken(on: request, refreshToken: refreshTokenDto.refreshToken)
        let user = try await tokensService.getUserByRefreshToken(on: request, refreshToken: refreshToken.token)

        let accessToken = try await tokensService.updateAccessTokens(on: request, forUser: user, andRefreshToken: refreshToken)
        return accessToken
    }
    
    /// Revoke refresh token.
    ///
    /// Endpoint will revoke all refresh tokens created in context of specified in Url user. Access to that endpoint have administrator
    /// and user mentioned in the Url (when user and `accessToken` match).
    ///
    /// > Important: Endpoint URL: `/api/v1/account/refresh-token/:userName`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/refresh-token/@johndoe" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -X DELETE
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    func revoke(request: Request) async throws -> HTTPStatus {
        guard let userName = request.parameters.get("username") else {
            throw Abort(.badRequest)
        }

        guard let authorizationPayload = request.auth.get(UserPayload.self) else {
            throw Abort(.unauthorized)
        }
        
        let usersService = request.application.services.usersService
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        let userFromDb = try await usersService.get(on: request.db, userName: userNameNormalized)

        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        // Administrator can revoke all refresh tokens.
        guard authorizationPayload.isAdministrator() || authorizationPayload.userName == user.userName else {
            throw Abort(.forbidden)
        }
        
        let tokensService = request.application.services.tokensService
        try await tokensService.revokeRefreshTokens(on: request, forUser: user)

        return HTTPStatus.ok
    }
    
    private func sendConfirmEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {
        let emailsService = request.application.services.emailsService
        try await emailsService.dispatchConfirmAccountEmail(on: request, user: user, redirectBaseUrl: redirectBaseUrl)
    }
}
