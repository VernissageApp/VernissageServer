//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Controler for generic account operation.
final class AccountController: RouteCollection {

    public static let uri: PathComponent = .constant("account")

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

    /// Sign-in user via login (usernane or email) and password.
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
        try await emailsService.dispatchConfirmAccountEmail(on: request, user: user, redirectBaseUrl: resendEmailConfirmationDto.redirectBaseUrl)

        return HTTPStatus.ok
    }
        
    /// Change password.
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

    /// Changing password.
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
    
    /// Refresh access_token token by sending refresh_token.
    func refresh(request: Request) async throws -> AccessTokenDto {
        let refreshTokenDto = try request.content.decode(RefreshTokenDto.self)
        let tokensService = request.application.services.tokensService

        let refreshToken = try await tokensService.validateRefreshToken(on: request, refreshToken: refreshTokenDto.refreshToken)
        let user = try await tokensService.getUserByRefreshToken(on: request, refreshToken: refreshToken.token)

        let accessToken = try await tokensService.updateAccessTokens(on: request, forUser: user, andRefreshToken: refreshToken)
        return accessToken
    }
    
    /// Revoke refresh token.
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
