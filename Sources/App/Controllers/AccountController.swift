//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

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
            .grouped(EventHandlerMiddleware(.accountRefresh))
            .post("refresh", use: refresh)

        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.accountChangePassword, storeRequest: false))
            .post("change-password", use: changePassword)

        accountGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsSuperUserMiddleware())
            .grouped(EventHandlerMiddleware(.accountRevoke))
            .post("revoke", ":username", use: revoke)
    }

    /// Sign-in user.
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

    /// Refresh token.
    func refresh(request: Request) async throws -> AccessTokenDto {
        let refreshTokenDto = try request.content.decode(RefreshTokenDto.self)
        let tokensService = request.application.services.tokensService

        let refreshToken = try await tokensService.validateRefreshToken(on: request, refreshToken: refreshTokenDto.refreshToken)
        let user = try await tokensService.getUserByRefreshToken(on: request, refreshToken: refreshToken.token)

        let accessToken = try await tokensService.updateAccessTokens(on: request, forUser: user, andRefreshToken: refreshToken)
        return accessToken
    }

    /// Change password.
    func changePassword(request: Request) async throws -> HTTPStatus {
        let authorizationPayload = try request.auth.require(UserPayload.self)

        let changePasswordRequestDto = try request.content.decode(ChangePasswordRequestDto.self)
        try ChangePasswordRequestDto.validate(content: request)

        let usersService = request.application.services.usersService

        try await usersService.changePassword(
            on: request,
            userId: authorizationPayload.id,
            currentPassword: changePasswordRequestDto.currentPassword,
            newPassword: changePasswordRequestDto.newPassword
        )

        return HTTPStatus.ok
    }

    /// Revoke refresh token
    func revoke(request: Request) async throws -> HTTPStatus {
        guard let userName = request.parameters.get("username") else {
            throw Abort(.badRequest)
        }

        let usersService = request.application.services.usersService
        let userNameNormalized = userName.replacingOccurrences(of: "@", with: "").uppercased()
        let userFromDb = try await usersService.get(on: request, userName: userNameNormalized)

        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        let tokensService = request.application.services.tokensService
        try await tokensService.revokeRefreshTokens(on: request, forUser: user)

        return HTTPStatus.ok
    }
}
