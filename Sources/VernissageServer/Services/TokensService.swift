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
    func createAccessTokens(forUser user: User, useCookies: Bool?, on request: Request) async throws -> AccessTokens
    func updateAccessTokens(forUser user: User, refreshToken: RefreshToken, regenerateRefreshToken: Bool?, useCookies: Bool?, on request: Request) async throws -> AccessTokens
    func validateRefreshToken(refreshToken: String, on request: Request) async throws -> RefreshToken
    func getUserByRefreshToken(refreshToken: String, on request: Request) async throws -> User
    func revokeRefreshTokens(forUser user: User, on request: Request) async throws
}

/// A service for managing authorization tokens.
final class TokensService: TokensServiceType {

    private let refreshTokenTime: TimeInterval = 30 * 24 * 60 * 60  // 30 days
    private let accessTokenTime: TimeInterval = 60 * 60             // 1 hour
    
    public func validateRefreshToken(refreshToken: String, on request: Request) async throws -> RefreshToken {
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
    
    public func createAccessTokens(forUser user: User, useCookies: Bool? = false, on request: Request) async throws -> AccessTokens {
        let accessTokenExpirationDate = Date().addingTimeInterval(TimeInterval(self.accessTokenTime))
        let refreshTokenExpirationDate = Date().addingTimeInterval(self.refreshTokenTime)

        let xsrfToken = self.createXsrfToken()
        let userPayload = try await self.createAuthenticationPayload(forUser: user, with: accessTokenExpirationDate, on: request)
        let accessToken = try await self.createAccessToken(forUser: userPayload, with: accessTokenExpirationDate, on: request)
        let refreshToken = try await self.createRefreshToken(forUser: user, with: refreshTokenExpirationDate, on: request)

        return AccessTokens(accessToken: accessToken,
                            refreshToken: refreshToken,
                            xsrfToken: xsrfToken,
                            accessTokenExpirationDate: accessTokenExpirationDate,
                            refreshTokenExpirationDate: refreshTokenExpirationDate,
                            userPayload: userPayload,
                            useCookies: useCookies == true)
    }
    
    public func updateAccessTokens(forUser user: User,
                                   refreshToken: RefreshToken,
                                   regenerateRefreshToken: Bool? = true,
                                   useCookies: Bool? = false,
                                   on request: Request) async throws -> AccessTokens {
        let accessTokenExpirationDate = Date().addingTimeInterval(TimeInterval(self.accessTokenTime))
        let refreshTokenExpirationDate = Date().addingTimeInterval(self.refreshTokenTime)
        
        let xsrfToken = self.createXsrfToken()
        let userPayload = try await self.createAuthenticationPayload(forUser: user, with: accessTokenExpirationDate, on: request)
        let accessToken = try await self.createAccessToken(forUser: userPayload, with: accessTokenExpirationDate, on: request)
        let refreshToken = try await  self.updateRefreshToken(forToken: refreshToken,
                                                              with: refreshTokenExpirationDate,
                                                              regenerate: regenerateRefreshToken == true,
                                                              on: request)
     
        return AccessTokens(accessToken: accessToken,
                            refreshToken: refreshToken,
                            xsrfToken: xsrfToken,
                            accessTokenExpirationDate: accessTokenExpirationDate,
                            refreshTokenExpirationDate: refreshTokenExpirationDate,
                            userPayload: userPayload,
                            useCookies: useCookies == true)
    }
    
    public func getUserByRefreshToken(refreshToken: String, on request: Request) async throws -> User {
        let refreshTokenFromDb = try await RefreshToken.query(on: request.db).with(\.$user).filter(\.$token == refreshToken).first()
                    
        guard let refreshToken = refreshTokenFromDb else {
            throw EntityNotFoundError.refreshTokenNotFound
        }
        
        if refreshToken.user.isBlocked {
            throw LoginError.userAccountIsBlocked
        }

        return refreshToken.user
    }
    
    private func createAccessToken(forUser authorizationPayload: UserPayload, with expirationDate: Date, on request: Request) async throws -> String {
        let accessToken = try request.jwt.sign(authorizationPayload)
        return accessToken
    }

    private func createRefreshToken(forUser user: User, with expirationDate: Date, on request: Request) async throws -> String {
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

    private func updateRefreshToken(forToken refreshToken: RefreshToken, with expirationDate: Date, regenerate: Bool, on request: Request) async throws -> String {
        refreshToken.token = regenerate ? String.createRandomString(length: 40) : refreshToken.token
        refreshToken.expiryDate = expirationDate

        try await refreshToken.save(on: request.db)
        return refreshToken.token
    }
    
    public func revokeRefreshTokens(forUser user: User, on request: Request) async throws {
        let refreshTokens = try await RefreshToken.query(on: request.db).filter(\.$user.$id == user.id!).all()
        
        try await withThrowingTaskGroup(of: Void.self) { _ in
            for refreshToken in refreshTokens {
                refreshToken.revoked = true
                try await refreshToken.save(on: request.db)
            }
        }
    }

    private func createAuthenticationPayload(forUser user: User, with expirationDate: Date, on request: Request) async throws -> UserPayload {

        guard let userId = user.id else {
            throw Abort(.unauthorized)
        }
        
        let userFromDb = try await User.query(on: request.db).with(\.$roles).filter(\.$id == userId).first()
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.executionContext)
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
