//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
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
            .grouped(CacheControlMiddleware(.noStore))
            .post("login", use: login)
        
        accountGroup
            .grouped(EventHandlerMiddleware(.accountLogout))
            .grouped(CacheControlMiddleware(.noStore))
            .post("logout", use: logout)
        
        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.accountIsEmailVerified))
            .grouped(CacheControlMiddleware(.noStore))
            .grouped("email")
            .get("verified", use: emailVerified)
        
        accountGroup
            .grouped(EventHandlerMiddleware(.accountConfirm))
            .grouped(CacheControlMiddleware(.noStore))
            .grouped("email")
            .post("confirm", use: confirm)
        
        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.accountConfirm))
            .grouped(CacheControlMiddleware(.noStore))
            .grouped("email")
            .post("resend", use: resend)
        
        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.accountChangeEmail))
            .grouped(CacheControlMiddleware(.noStore))
            .put("email", use: changeEmail)
        
        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.accountChangePassword, storeRequest: false))
            .grouped(CacheControlMiddleware(.noStore))
            .put("password", use: changePassword)

        accountGroup
            .grouped(EventHandlerMiddleware(.accountForgotToken))
            .grouped(CacheControlMiddleware(.noStore))
            .grouped("forgot")
            .post("token", use: forgotPasswordToken)
        
        accountGroup
            .grouped(EventHandlerMiddleware(.accountForgotConfirm, storeRequest: false))
            .grouped(CacheControlMiddleware(.noStore))
            .grouped("forgot")
            .post("confirm", use: forgotPasswordConfirm)
        
        accountGroup
            .grouped(EventHandlerMiddleware(.accountRefresh))
            .grouped(CacheControlMiddleware(.noStore))
            .post("refresh-token", use: refresh)
        
        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.accountRevoke))
            .grouped(CacheControlMiddleware(.noStore))
            .delete("refresh-token", ":username", use: revoke)
        
        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.accountGetTwoFactorToken))
            .grouped(CacheControlMiddleware(.noStore))
            .get("get-2fa-token", use: getTwoFactorToken)
        
        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.accountEnableTwoFactorAuthentication))
            .grouped(CacheControlMiddleware(.noStore))
            .post("enable-2fa", use: enableTwoFactorAuthentication)
        
        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.accountDisableTwoFactorAuthentication))
            .grouped(CacheControlMiddleware(.noStore))
            .post("disable-2fa", use: disableTwoFactorAuthentication)
    }
}

/// Controller for generic account operation.
///
/// Actions in the controller are designed to handle basic operations related to a user's account in the system,
/// such as logging in, changing email, password, etc.
///
/// > Important: Base controller URL: `/api/v1/account`.
struct AccountController {

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
    @Sendable
    func login(request: Request) async throws -> Response {
        let loginRequestDto = try request.content.decode(LoginRequestDto.self)
        let usersService = request.application.services.usersService
        let isMachineTrusted = self.isMachineTrusted(on: request)

        let user = try await usersService.login(userNameOrEmail: loginRequestDto.userNameOrEmail,
                                                password: loginRequestDto.password,
                                                isMachineTrusted: isMachineTrusted,
                                                on: request)
        
        let tokensService = request.application.services.tokensService
        let accessToken = try await tokensService.createAccessTokens(forUser: user,
                                                                     useCookies: loginRequestDto.useCookies,
                                                                     useLongAccessToken: false,
                                                                     useApplication: nil,
                                                                     useScopes: nil,
                                                                     on: request)
        
        return try await self.createAccessTokenResponse(on: request,
                                                        accessToken: accessToken,
                                                        trustMachine: loginRequestDto.trustMachine)
    }
    
    /// This is a endpoint for signing out.
    ///
    /// This endpoint is signing out user from the system. His main responsibility is to clear cookies from the browser.
    /// Only serve have access to the cookies and only server can clear them.
    ///
    /// > Important: Endpoint URL: `/api/v1/account/logout`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/logout" \
    /// -X POST \
    /// -H "Content-Type: application/json"
    /// ```
    @Sendable
    func logout(request: Request) async throws -> Response {
        return try await self.clearCookies(on: request)
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
    /// - Throws: `RegisterError.disposableEmailCannotBeUsed` if disposabled email has been used.
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    @Sendable
    func changeEmail(request: Request) async throws -> HTTPResponseStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let user = try await User.find(authorizationPayloadId, on: request.db) else {
            throw Abort(.notFound)
        }

        try ChangeEmailDto.validate(content: request)
        let changeEmailDto = try request.content.decode(ChangeEmailDto.self)

        let usersService = request.application.services.usersService
        try await usersService.validateEmail(email: changeEmailDto.email, on: request)
        
        // Change email in database.
        try await usersService.changeEmail(
            userId: authorizationPayloadId,
            email: changeEmailDto.email,
            on: request
        )
        
        // Send email with email confirmation message.
        try await self.sendConfirmEmail(on: request, user: user, redirectBaseUrl: changeEmailDto.redirectBaseUrl)

        return HTTPStatus.ok
    }
    
    /// Information about email verification.
    ///
    /// Endpoint should be used for check if email has been verified by user.
    ///
    /// > Important: Endpoint URL: `/api/v1/account/email/verified`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/email/verified" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "result": true
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint ``ConfirmEmailRequestDto``.
    ///
    /// - Returns: ``BooleanResponseDto`` entity.
    ///
    /// - Throws: `ChangePasswordError.userNotFound` if signed user was not found in the database.
    @Sendable
    func emailVerified(request: Request) async throws -> BooleanResponseDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        guard let user = try await User.find(authorizationPayloadId, on: request.db) else {
            throw EntityNotFoundError.userNotFound
        }
                
        return BooleanResponseDto(result: user.emailWasConfirmed == true)
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
    @Sendable
    func confirm(request: Request) async throws -> HTTPResponseStatus {
        let confirmEmailRequestDto = try request.content.decode(ConfirmEmailRequestDto.self)
        let usersService = request.application.services.usersService

        guard let userId = confirmEmailRequestDto.id.toId() else {
            throw ConfirmEmailError.invalidIdOrToken
        }
        
        try await usersService.confirmEmail(userId: userId,
                                            confirmationGuid: confirmEmailRequestDto.confirmationGuid,
                                            on: request)

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
    @Sendable
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
        try await emailsService.dispatchConfirmAccountEmail(user: user,
                                                            redirectBaseUrl: resendEmailConfirmationDto.redirectBaseUrl,
                                                            on: request)

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
    @Sendable
    func changePassword(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        try ChangePasswordRequestDto.validate(content: request)
        let changePasswordRequestDto = try request.content.decode(ChangePasswordRequestDto.self)

        let usersService = request.application.services.usersService

        try await usersService.changePassword(
            userId: authorizationPayloadId,
            currentPassword: changePasswordRequestDto.currentPassword,
            newPassword: changePasswordRequestDto.newPassword,
            on: request
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
    @Sendable
    func forgotPasswordToken(request: Request) async throws -> HTTPResponseStatus {
        let forgotPasswordRequestDto = try request.content.decode(ForgotPasswordRequestDto.self)
        
        let usersService = request.application.services.usersService
        let emailsService = request.application.services.emailsService

        let user = try await usersService.forgotPassword(email: forgotPasswordRequestDto.email, on: request)
        
        try await emailsService.dispatchForgotPasswordEmail(user: user,
                                                            redirectBaseUrl: forgotPasswordRequestDto.redirectBaseUrl,
                                                            on: request)

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
    @Sendable
    func forgotPasswordConfirm(request: Request) async throws -> HTTPResponseStatus {
        try ForgotPasswordConfirmationRequestDto.validate(content: request)
        let confirmationDto = try request.content.decode(ForgotPasswordConfirmationRequestDto.self)

        let usersService = request.application.services.usersService
        try await usersService.confirmForgotPassword(
            forgotPasswordGuid: confirmationDto.forgotPasswordGuid,
            password: confirmationDto.password,
            on: request
        )

        return HTTPStatus.ok
    }
    
    /// Refresh `accessToken` token by sending `refreshToken`.
    ///
    /// Endpoint will regenerate new `accessToken` based on `refreshToken` which has been generated during the login process.
    /// This is the only endpoint to which the `refreshToken` should be sent, only when the `accessToken` expires (or a moment before it expires).
    /// Refresh token can be send in the ``RefreshTokenDto`` object or in the `refresh-token` cookie. When request doesn't contain
    /// refresh token (in body or cookie) `NoContent` response is produced.
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
    @Sendable
    func refresh(request: Request) async throws -> Response {
        guard let oldRefreshToken = try self.getRefreshToken(on: request) else {
            return Response(status: HTTPStatus.noContent)
        }
        
        let tokensService = request.application.services.tokensService

        let refreshTokenFromDb = try await tokensService.validateRefreshToken(refreshToken: oldRefreshToken.refreshToken, on: request)
        let user = try await tokensService.getUserByRefreshToken(refreshToken: refreshTokenFromDb.token, on: request)

        let accessToken = try await tokensService.updateAccessTokens(forUser: user,
                                                                     refreshToken: refreshTokenFromDb,
                                                                     regenerateRefreshToken: oldRefreshToken.regenerateRefreshToken,
                                                                     useCookies: oldRefreshToken.useCookies,
                                                                     useLongAccessToken: false,
                                                                     useApplication: nil,
                                                                     useScopes: nil,
                                                                     on: request)

        return try await self.createAccessTokenResponse(on: request, accessToken: accessToken)
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
    @Sendable
    func revoke(request: Request) async throws -> HTTPStatus {
        guard let userName = request.parameters.get("username") else {
            throw Abort(.badRequest)
        }

        guard let authorizationPayload = request.auth.get(UserPayload.self) else {
            throw Abort(.unauthorized)
        }
        
        let usersService = request.application.services.usersService
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        let userFromDb = try await usersService.get(userName: userNameNormalized, on: request.db)

        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        // Administrator can revoke all refresh tokens.
        guard authorizationPayload.isAdministrator() || authorizationPayload.userName == user.userName else {
            throw Abort(.forbidden)
        }
        
        let tokensService = request.application.services.tokensService
        try await tokensService.revokeRefreshTokens(forUser: user, on: request)

        return HTTPStatus.ok
    }
    
    /// Generate two factor token (TOTP).
    ///
    /// Endpoint will generate TOTP two factor token. Token can be used in applications like Authy or Goole Authenticator.
    ///
    /// > Important: Endpoint URL: `/api/v1/account/get-2fa-token
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/get-2fa-token" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "key": "ciOiJSUzUxMiIsInR5cCI6IkpXVCJ9",
    ///     "label": "johndoe",
    ///     "issuer: "Vernissage",
    ///     "url": "otpauth://totp/johndoe?secret=34rrk23234j334rer332e&issuer=Vernissage",
    ///     "backupCodes": ["34rmr2kmo2mo2", "232l3kml23rer"]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `TwoFactorTokenError.cannotEncodeKey` if cannot encode key to base32 data..
    @Sendable
    func getTwoFactorToken(request: Request) async throws -> TwoFactorTokenDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        guard let user = try await User.find(authorizationPayloadId, on: request.db) else {
            throw EntityNotFoundError.userNotFound
        }
        
        let twoFactorTokensService = request.application.services.twoFactorTokensService
        if let twoFactorToken = try await twoFactorTokensService.find(for: authorizationPayloadId, on: request.db) {
            return TwoFactorTokenDto(from: twoFactorToken, for: user)
        }
        
        let newTwoFactorTokenId = request.application.services.snowflakeService.generate()
        let twoFactorToken = try twoFactorTokensService.generate(for: user, withId: newTwoFactorTokenId)
        try await twoFactorToken.save(on: request.db)
        
        return TwoFactorTokenDto(from: twoFactorToken, for: user)
    }
    
    /// Enable two factor token authorization (TOTP).
    ///
    /// Endpoint will enable two factor authontication. Code generated by authenticator app have to be sent in the header: `X-Auth-2FA`.
    ///
    /// > Important: Endpoint URL: `/api/v1/account/enable-2fa
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/enable-2fa" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -H "X-Auth-2FA: [CODE]" \
    /// -X POST
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `TwoFactorTokenError.cannotEncodeKey` if cannot encode key to base32 data.
    /// - Throws: `TwoFactorTokenError.headerNotExists` if header `X-Auth-2FA` with code not exists.
    /// - Throws: `EntityNotFoundError.twoFactorTokenNotFound` if two factor token not exists.
    /// - Throws: `TwoFactorTokenError.codeNotValid` if code is not valid.
    @Sendable
    func enableTwoFactorAuthentication(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        guard let user = try await User.find(authorizationPayloadId, on: request.db) else {
            throw EntityNotFoundError.userNotFound
        }
        
        if user.twoFactorEnabled {
            return HTTPStatus.ok
        }
        
        guard let token = request.headers.first(name: Constants.twoFactorTokenHeader) else {
            throw TwoFactorTokenError.headerNotExists
        }
        
        let twoFactorTokensService = request.application.services.twoFactorTokensService
        guard let twoFactorToken = try await twoFactorTokensService.find(for: authorizationPayloadId, on: request.db) else {
            throw EntityNotFoundError.twoFactorTokenNotFound
        }
        
        guard try twoFactorTokensService.validate(token, twoFactorToken: twoFactorToken, allowBackupCode: false) else {
            throw TwoFactorTokenError.tokenNotValid
        }
        
        user.twoFactorEnabled = true
        try await user.save(on: request.db)
        
        return HTTPStatus.ok
    }
    
    /// Disable two factor token authorization (TOTP).
    ///
    /// To disable 2FA it's mandatory to send correct actual code generated by the app (Authy or Google Authenticator).
    /// Code have to be send it the header: `X-Auth-2FA`.
    ///
    /// > Important: Endpoint URL: `/api/v1/account/disable-2fa
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/account/enable-2fa" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -H "X-Auth-2FA: [CODE]" \
    /// -X POST
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `TwoFactorTokenError.cannotEncodeKey` if cannot encode key to base32 data.
    /// - Throws: `TwoFactorTokenError.headerNotExists` if header `X-Auth-2FA` with code not exists.
    /// - Throws: `EntityNotFoundError.twoFactorTokenNotFound` if two factor token not exists.
    /// - Throws: `TwoFactorTokenError.codeNotValid` if code is not valid.
    @Sendable
    func disableTwoFactorAuthentication(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        guard let user = try await User.find(authorizationPayloadId, on: request.db) else {
            throw EntityNotFoundError.userNotFound
        }
        
        if !user.twoFactorEnabled {
            return HTTPStatus.ok
        }
        
        guard let token = request.headers.first(name: Constants.twoFactorTokenHeader) else {
            throw TwoFactorTokenError.headerNotExists
        }
        
        let twoFactorTokensService = request.application.services.twoFactorTokensService
        guard let twoFactorToken = try await twoFactorTokensService.find(for: authorizationPayloadId, on: request.db) else {
            throw EntityNotFoundError.twoFactorTokenNotFound
        }
        
        guard try twoFactorTokensService.validate(token, twoFactorToken: twoFactorToken, allowBackupCode: false) else {
            throw TwoFactorTokenError.tokenNotValid
        }
        
        try await request.db.transaction { database in
            user.twoFactorEnabled = false

            try await twoFactorToken.delete(on: database)
            try await user.save(on: database)
        }
        
        return HTTPStatus.ok
    }
    
    private func sendConfirmEmail(on request: Request, user: User, redirectBaseUrl: String) async throws {
        let emailsService = request.application.services.emailsService
        try await emailsService.dispatchConfirmAccountEmail(user: user, redirectBaseUrl: redirectBaseUrl, on: request)
    }
    
    private func createAccessTokenResponse(on request: Request, accessToken: AccessTokens, trustMachine: Bool? = nil) async throws -> Response {
        let response = try await accessToken.toAccessTokenDto().encodeResponse(for: request)
        response.status = .ok
        
        if accessToken.useCookies {
            let cookieAccessToken = HTTPCookies.Value(string: accessToken.accessToken,
                                                      expires: accessToken.accessTokenExpirationDate,
                                                      isSecure: request.application.environment != .development,
                                                      isHTTPOnly: true,
                                                      sameSite: HTTPCookies.SameSitePolicy.lax)
            
            let cookieRefreshToken = HTTPCookies.Value(string: accessToken.refreshToken,
                                                       expires: accessToken.refreshTokenExpirationDate,
                                                       isSecure: request.application.environment != .development,
                                                       isHTTPOnly: true,
                                                       sameSite: HTTPCookies.SameSitePolicy.lax)
            
            let xsrfToken = HTTPCookies.Value(string: accessToken.xsrfToken,
                                              expires: accessToken.refreshTokenExpirationDate,
                                              isSecure: request.application.environment != .development,
                                              isHTTPOnly: true,
                                              sameSite: HTTPCookies.SameSitePolicy.lax)
            
            response.cookies[Constants.accessTokenName] = cookieAccessToken
            response.cookies[Constants.refreshTokenName] = cookieRefreshToken
            response.cookies[Constants.xsrfTokenName] = xsrfToken
            
            if let trustMachine, trustMachine {
                let isMachineTrustedTime: TimeInterval = 30 * 24 * 60 * 60  // 30 days
                let isMachineTrustedExpirationDate = Date().addingTimeInterval(isMachineTrustedTime)
                let isMachineTrustedCookie = HTTPCookies.Value(string: "\(trustMachine)",
                                                               expires: isMachineTrustedExpirationDate,
                                                               isSecure: request.application.environment != .development,
                                                               isHTTPOnly: true,
                                                               sameSite: HTTPCookies.SameSitePolicy.lax)
                response.cookies[Constants.isMachineTrustedName] = isMachineTrustedCookie
            }
        }
        
        return response
    }
    
    private func clearCookies(on request: Request) async throws -> Response {
        let booleanResponseDto = BooleanResponseDto(result: true)
        let response = try await booleanResponseDto.encodeResponse(for: request)
        response.status = .ok
        
        let cookieAccessToken = HTTPCookies.Value(string: "",
                                                  maxAge: 0,
                                                  isSecure: request.application.environment != .development,
                                                  isHTTPOnly: true,
                                                  sameSite: HTTPCookies.SameSitePolicy.lax)

        let cookieRefreshToken = HTTPCookies.Value(string: "",
                                                   maxAge: 0,
                                                   isSecure: request.application.environment != .development,
                                                   isHTTPOnly: true,
                                                   sameSite: HTTPCookies.SameSitePolicy.lax)
        
        let xsrfToken = HTTPCookies.Value(string: "",
                                          maxAge: 0,
                                          isSecure: request.application.environment != .development,
                                          isHTTPOnly: true,
                                          sameSite: HTTPCookies.SameSitePolicy.lax)
        
        response.cookies[Constants.accessTokenName] = cookieAccessToken
        response.cookies[Constants.refreshTokenName] = cookieRefreshToken
        response.cookies[Constants.xsrfTokenName] = xsrfToken

        return response
    }
    
    private func getRefreshToken(on request: Request) throws -> RefreshTokenDto? {
        if let cookieRefreshToken = request.cookies[Constants.refreshTokenName], cookieRefreshToken.string.isEmpty == false {
            return RefreshTokenDto(refreshToken: cookieRefreshToken.string, useCookies: true)
        }

        guard (request.body.data?.readableBytes ?? 0) > 0 else {
            return nil
        }

        let refreshTokenDto = try request.content.decode(RefreshTokenDto.self)
        return refreshTokenDto
    }
    
    private func isMachineTrusted(on request: Request) -> Bool {
        if let isMachineTrusted = request.cookies[Constants.isMachineTrustedName], isMachineTrusted.string.isEmpty == false {
            return true
        }

        return false
    }
}
