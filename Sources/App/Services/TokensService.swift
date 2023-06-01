//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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

protocol TokensServiceType {
    func createAccessTokens(on request: Request, forUser user: User) async throws-> AccessTokenDto
    func updateAccessTokens(on request: Request, forUser user: User, andRefreshToken refreshToken: RefreshToken) async throws -> AccessTokenDto
    func validateRefreshToken(on request: Request, refreshToken: String) async throws -> RefreshToken
    func getUserByRefreshToken(on request: Request, refreshToken: String) async throws -> User
    func revokeRefreshTokens(on request: Request, forUser user: User) async throws
}

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

        if refreshToken.expiryDate < Date()  {
            throw RefreshTokenError.refreshTokenExpired
        }
        
        return refreshToken
    }
    
    public func createAccessTokens(on request: Request, forUser user: User) async throws -> AccessTokenDto {
        let accessToken = try await self.createAccessToken(on: request, forUser: user)
        let refreshToken = try await self.createRefreshToken(on: request, forUser: user)

        return AccessTokenDto(accessToken: accessToken, refreshToken: refreshToken)
    }
    
    public func updateAccessTokens(on request: Request, forUser user: User, andRefreshToken refreshToken: RefreshToken) async throws -> AccessTokenDto {
        let accessToken = try await self.createAccessToken(on: request, forUser: user)
        let refreshToken = try await  self.updateRefreshToken(on: request, forToken: refreshToken)
     
        return AccessTokenDto(accessToken: accessToken, refreshToken: refreshToken)
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
    
    private func createAccessToken(on request: Request, forUser user: User) async throws -> String {
        let authorizationPayload = try await self.createAuthenticationPayload(request: request, forUser: user)

        let accessToken = try request.jwt.sign(authorizationPayload)
        return accessToken
    }

    private func createRefreshToken(on request: Request, forUser user: User) async throws -> String {
        guard let userId = user.id else {
            throw RefreshTokenError.userIdNotSpecified
        }

        let token = String.createRandomString(length: 40)
        let expiryDate = Date().addingTimeInterval(self.refreshTokenTime)
        let refreshToken = RefreshToken(userId: userId, token: token, expiryDate: expiryDate)

        try await refreshToken.save(on: request.db)
        return refreshToken.token
    }

    private func updateRefreshToken(on request: Request, forToken refreshToken: RefreshToken) async throws -> String {
        refreshToken.token = String.createRandomString(length: 40)
        refreshToken.expiryDate = Date().addingTimeInterval(self.refreshTokenTime)

        try await refreshToken.save(on: request.db)
        return refreshToken.token
    }
    
    public func revokeRefreshTokens(on request: Request, forUser user: User) async throws {
        let refreshTokens = try await RefreshToken.query(on: request.db).filter(\.$user.$id == user.id!).all()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for refreshToken in refreshTokens {
                refreshToken.revoked = true
                try await refreshToken.save(on: request.db)
            }
        }
    }

    private func createAuthenticationPayload(request: Request, forUser user: User) async throws -> UserPayload {

        guard let userId = user.id else {
            throw Abort(.unauthorized)
        }
        
        let userFromDb = try await User.query(on: request.db).with(\.$roles).filter(\.$id == userId).first()
        let superUserRoles = userFromDb?.roles.filter({ $0.hasSuperPrivileges == true }).count

        let expirationDate = Date().addingTimeInterval(TimeInterval(self.accessTokenTime))

        let authorizationPayload = UserPayload(
            id: userId,
            userName: user.userName,
            email: user.email,
            name: user.name,
            exp: expirationDate,
            gravatarHash: user.gravatarHash,
            roles: userFromDb?.roles.map { $0.code } ?? [],
            isSuperUser: superUserRoles ?? 0 > 0
        )

        return authorizationPayload
    }
}
