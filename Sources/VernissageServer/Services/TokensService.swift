//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct TokensServiceKey: StorageKey {
        typealias Value = TokensServiceType
    }

    var tokensService: TokensServiceType {
        get {
            self.application.storage[TokensServiceKey.self] ?? TokensService()
        }
        nonmutating set {
            self.application.storage[TokensServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol TokensServiceType: Sendable {
    func createAccessTokens(on request: Request, forUser user: User, useCookies: Bool?) async throws -> AccessTokens
    func updateAccessTokens(on request: Request, forUser user: User, refreshToken: RefreshToken, regenerateRefreshToken: Bool?, useCookies: Bool?) async throws -> AccessTokens
    func validateRefreshToken(on request: Request, refreshToken: String) async throws -> RefreshToken
    func getUserByRefreshToken(on request: Request, refreshToken: String) async throws -> User
    func revokeRefreshTokens(on request: Request, forUser user: User) async throws
}

/// A service for managing authorization tokens.
final class TokensService: TokensServiceType {

    private let refreshTokenTime: TimeInterval = 30 * 24 * 60 * 60  // 30 days
    private let accessTokenTime: TimeInterval = 60 * 60             // 1 hour
    
    public func validateRefreshToken(on request: Request, refreshToken: String) async throws -> RefreshToken {
        let refreshTokenFromDb = try await RefreshToken.query(on: request.db).filter(\.$token == refreshToken).first()

        guard let refreshToken = refreshTokenFromDb else {
            throw EntityNotFoundError.refreshTokenNotFound
        }

        if refreshToken.revoked {
            throw RefreshTokenError.refreshTokenRevoked
        }

        let currentDate = Date()
        if refreshToken.expiryDate < currentDate {
            throw RefreshTokenError.refreshTokenExpired
        }
        
        return refreshToken
    }
    
    public func createAccessTokens(on request: Request, forUser user: User, useCookies: Bool? = false) async throws -> AccessTokens {
        let accessTokenExpirationDate = Date().addingTimeInterval(TimeInterval(self.accessTokenTime))
        let refreshTokenExpirationDate = Date().addingTimeInterval(self.refreshTokenTime)

        let xsrfToken = self.createXsrfToken()
        let userPayload = try await self.createAuthenticationPayload(request: request, forUser: user, with: accessTokenExpirationDate)
        let accessToken = try await self.createAccessToken(on: request, forUser: userPayload, with: accessTokenExpirationDate)
        let refreshToken = try await self.createRefreshToken(on: request, forUser: user, with: refreshTokenExpirationDate)

        return AccessTokens(accessToken: accessToken,
                            refreshToken: refreshToken,
                            xsrfToken: xsrfToken,
                            accessTokenExpirationDate: accessTokenExpirationDate,
                            refreshTokenExpirationDate: refreshTokenExpirationDate,
                            userPayload: userPayload,
                            useCookies: useCookies == true)
    }
    
    public func updateAccessTokens(on request: Request,
                                   forUser user: User,
                                   refreshToken: RefreshToken,
                                   regenerateRefreshToken: Bool? = true,
                                   useCookies: Bool? = false) async throws -> AccessTokens {
        let accessTokenExpirationDate = Date().addingTimeInterval(TimeInterval(self.accessTokenTime))
        let refreshTokenExpirationDate = Date().addingTimeInterval(self.refreshTokenTime)
        
        let xsrfToken = self.createXsrfToken()
        let userPayload = try await self.createAuthenticationPayload(request: request, forUser: user, with: accessTokenExpirationDate)
        let accessToken = try await self.createAccessToken(on: request, forUser: userPayload, with: accessTokenExpirationDate)
        let refreshToken = try await  self.updateRefreshToken(on: request,
                                                              forToken: refreshToken,
                                                              with: refreshTokenExpirationDate,
                                                              regenerate: regenerateRefreshToken == true)
     
        return AccessTokens(accessToken: accessToken,
                            refreshToken: refreshToken,
                            xsrfToken: xsrfToken,
                            accessTokenExpirationDate: accessTokenExpirationDate,
                            refreshTokenExpirationDate: refreshTokenExpirationDate,
                            userPayload: userPayload,
                            useCookies: useCookies == true)
    }
    
    public func getUserByRefreshToken(on request: Request, refreshToken: String) async throws -> User {
        let refreshTokenFromDb = try await RefreshToken.query(on: request.db).with(\.$user).filter(\.$token == refreshToken).first()
                    
        guard let refreshToken = refreshTokenFromDb else {
            throw EntityNotFoundError.refreshTokenNotFound
        }
        
        if refreshToken.user.isBlocked {
            throw LoginError.userAccountIsBlocked
        }

        return refreshToken.user
    }
    
    private func createAccessToken(on request: Request, forUser authorizationPayload: UserPayload, with expirationDate: Date) async throws -> String {
        let accessToken = try request.jwt.sign(authorizationPayload)
        return accessToken
    }

    private func createRefreshToken(on request: Request, forUser user: User, with expirationDate: Date) async throws -> String {
        guard let userId = user.id else {
            throw RefreshTokenError.userIdNotSpecified
        }

        let token = String.createRandomString(length: 40)
        let id = request.application.services.snowflakeService.generate()
        let refreshToken = RefreshToken(id: id, userId: userId, token: token, expiryDate: expirationDate)

        try await refreshToken.save(on: request.db)
        return refreshToken.token
    }
    
    private func createXsrfToken() -> String {
        return String.createRandomString(length: 64)
    }

    private func updateRefreshToken(on request: Request, forToken refreshToken: RefreshToken, with expirationDate: Date, regenerate: Bool) async throws -> String {
        refreshToken.token = regenerate ? String.createRandomString(length: 40) : refreshToken.token
        refreshToken.expiryDate = expirationDate

        try await refreshToken.save(on: request.db)
        return refreshToken.token
    }
    
    public func revokeRefreshTokens(on request: Request, forUser user: User) async throws {
        let refreshTokens = try await RefreshToken.query(on: request.db).filter(\.$user.$id == user.id!).all()
        
        try await withThrowingTaskGroup(of: Void.self) { _ in
            for refreshToken in refreshTokens {
                refreshToken.revoked = true
                try await refreshToken.save(on: request.db)
            }
        }
    }

    private func createAuthenticationPayload(request: Request, forUser user: User, with expirationDate: Date) async throws -> UserPayload {

        guard let userId = user.id else {
            throw Abort(.unauthorized)
        }
        
        let userFromDb = try await User.query(on: request.db).with(\.$roles).filter(\.$id == userId).first()
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let avatarUrl = self.getAvatarUrl(user: user, baseStoragePath: baseStoragePath)
        let headerUrl = self.getHeaderUrl(user: user, baseStoragePath: baseStoragePath)

        let authorizationPayload = UserPayload(
            id: "\(userId)",
            userName: user.userName,
            email: user.email,
            name: user.name,
            exp: expirationDate,
            avatarUrl: avatarUrl,
            headerUrl: headerUrl,
            roles: userFromDb?.roles.map { $0.code } ?? [],
            application: Constants.applicationName
        )

        return authorizationPayload
    }
    
    private func getAvatarUrl(user: User, baseStoragePath: String) -> String? {
        guard let avatarFileName = user.avatarFileName else {
            return nil
        }
        
        return baseStoragePath.finished(with: "/") + avatarFileName
    }
    
    private func getHeaderUrl(user: User, baseStoragePath: String) -> String? {
        guard let headerFileName = user.headerFileName else {
            return nil
        }
        
        return baseStoragePath.finished(with: "/") + headerFileName
    }
}
