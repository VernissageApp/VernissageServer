//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct UsersServiceKey: StorageKey {
        typealias Value = UsersServiceType
    }

    var usersService: UsersServiceType {
        get {
            self.application.storage[UsersServiceKey.self] ?? UsersService()
        }
        nonmutating set {
            self.application.storage[UsersServiceKey.self] = newValue
        }
    }
}

protocol UsersServiceType {
    func get(on request: Request, userName: String) async throws -> User?
    func get(on request: Request, account: String) async throws -> User?
    func login(on request: Request, userNameOrEmail: String, password: String) async throws -> User
    func login(on request: Request, authenticateToken: String) async throws -> User
    func forgotPassword(on request: Request, email: String) async throws -> User
    func confirmForgotPassword(on request: Request, forgotPasswordGuid: String, password: String) async throws
    func changePassword(on request: Request, userId: UUID, currentPassword: String, newPassword: String) async throws
    func confirmEmail(on request: Request, userId: UUID, confirmationGuid: String) async throws
    func isUserNameTaken(on request: Request, userName: String) async throws -> Bool
    func isEmailConnected(on request: Request, email: String) async throws -> Bool
    func validateUserName(on request: Request, userName: String) async throws
    func validateEmail(on request: Request, email: String?) async throws
    func updateUser(on request: Request, userDto: UserDto, userNameNormalized: String) async throws -> User
    func deleteUser(on request: Request, userNameNormalized: String) async throws
    func createGravatarHash(from email: String) -> String
}

final class UsersService: UsersServiceType {

    func get(on request: Request, userName: String) async throws -> User? {
        let userNameNormalized = userName.uppercased()
        return try await User.query(on: request.db).filter(\.$userNameNormalized == userNameNormalized).first()
    }

    func get(on request: Request, account: String) async throws -> User? {
        let accountNormalized = account.uppercased()
        return try await User.query(on: request.db).filter(\.$accountNormalized == accountNormalized).first()
    }
    
    func login(on request: Request, userNameOrEmail: String, password: String) async throws -> User {

        let userNameOrEmailNormalized = userNameOrEmail.uppercased()

        let userFromDb = try await User.query(on: request.db).group(.or) { userNameGroup in
            userNameGroup.filter(\.$userNameNormalized == userNameOrEmailNormalized)
            userNameGroup.filter(\.$emailNormalized == userNameOrEmailNormalized)
        }.first()

        guard let user = userFromDb else {
            throw LoginError.invalidLoginCredentials
        }

        let passwordHash = try Password.hash(password, withSalt: user.salt)
        if user.password != passwordHash {
            throw LoginError.invalidLoginCredentials
        }

        if !user.emailWasConfirmed {
            throw LoginError.emailNotConfirmed
        }

        if user.isBlocked {
            throw LoginError.userAccountIsBlocked
        }

        return user
    }
    
    func login(on request: Request, authenticateToken: String) async throws -> User {
        let externalUser = try await ExternalUser.query(on: request.db).with(\.$user)
            .filter(\.$authenticationToken == authenticateToken).first()
        
        guard let externalUser = externalUser else {
            throw OpenIdConnectError.invalidAuthenticateToken
        }
        
        guard let tokenCreatedAt = externalUser.tokenCreatedAt else {
            throw OpenIdConnectError.authenticateTokenExpirationDateNotFound
        }
        
        if tokenCreatedAt.addingTimeInterval(60) < Date() {
            throw OpenIdConnectError.autheticateTokenExpired
        }

        if externalUser.user.isBlocked {
            throw OpenIdConnectError.userAccountIsBlocked
        }

        return externalUser.user
    }

    func forgotPassword(on request: Request, email: String) async throws -> User {
        let emailNormalized = email.uppercased()

        let userFromDb = try await User.query(on: request.db).filter(\.$emailNormalized == emailNormalized).first()

        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        if user.isBlocked {
            throw ForgotPasswordError.userAccountIsBlocked
        }

        user.forgotPasswordGuid = UUID.init().uuidString
        user.forgotPasswordDate = Date()

        try await user.save(on: request.db)
        return user
    }

    func confirmForgotPassword(on request: Request, forgotPasswordGuid: String, password: String) async throws {
        let userFromDb = try await User.query(on: request.db).filter(\.$forgotPasswordGuid == forgotPasswordGuid).first()

        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        if user.isBlocked {
            throw ForgotPasswordError.userAccountIsBlocked
        }

        guard let forgotPasswordDate = user.forgotPasswordDate else {
            throw ForgotPasswordError.tokenNotGenerated
        }

        let hoursDifference = Calendar.current.dateComponents([.hour], from: forgotPasswordDate, to: Date()).hour ?? 0
        if hoursDifference > 6 {
            throw ForgotPasswordError.tokenExpired
        }
        
        user.forgotPasswordGuid = nil
        user.forgotPasswordDate = nil
        user.emailWasConfirmed = true
        
        do {
            user.salt = Password.generateSalt()
            user.password = try Password.hash(password, withSalt: user.salt)
        } catch {
            throw ForgotPasswordError.passwordNotHashed
        }

        try await user.save(on: request.db)
    }

    func changePassword(on request: Request, userId: UUID, currentPassword: String, newPassword: String) async throws {
        let userFromDb = try await User.query(on: request.db).filter(\.$id == userId).first()

        guard let user = userFromDb else {
            throw ChangePasswordError.userNotFound
        }

        let currentPasswordHash = try Password.hash(currentPassword, withSalt: user.salt)
        if user.password != currentPasswordHash {
            throw ChangePasswordError.invalidOldPassword
        }

        if !user.emailWasConfirmed {
            throw ChangePasswordError.emailNotConfirmed
        }

        if user.isBlocked {
            throw ChangePasswordError.userAccountIsBlocked
        }

        let salt = Password.generateSalt()
        let newPasswordHash = try Password.hash(newPassword, withSalt: salt)

        user.password = newPasswordHash
        user.salt = salt

        try await user.update(on: request.db)
    }

    func confirmEmail(on request: Request, userId: UUID, confirmationGuid: String) async throws {
        let userFromDb = try await User.find(userId, on: request.db)

        guard let user = userFromDb else {
            throw RegisterError.invalidIdOrToken
        }

        guard user.emailConfirmationGuid == confirmationGuid else {
            throw RegisterError.invalidIdOrToken
        }

        user.emailWasConfirmed = true
        try await user.save(on: request.db)
    }

    func isUserNameTaken(on request: Request, userName: String) async throws-> Bool {

        let userNameNormalized = userName.uppercased()

        let userFromDb = try await User.query(on: request.db).filter(\.$userNameNormalized == userNameNormalized).first()
        if userFromDb != nil {
            return true
        }

        return false
    }

    func isEmailConnected(on request: Request, email: String) async throws -> Bool {

        let emailNormalized = email.uppercased()

        let userFromDb = try await User.query(on: request.db).filter(\.$emailNormalized == emailNormalized).first()
        if userFromDb != nil {
            return true
        }

        return false
    }
    
    func validateUserName(on request: Request, userName: String) async throws {
        let userNameNormalized = userName.uppercased()
        let user = try await User.query(on: request.db).filter(\.$userNameNormalized == userNameNormalized).first()
        if user != nil {
            throw RegisterError.userNameIsAlreadyTaken
        }
    }

    func validateEmail(on request: Request, email: String?) async throws {
        let emailNormalized = (email ?? "").uppercased()
        let user = try await User.query(on: request.db).filter(\.$emailNormalized == emailNormalized).first()
        if user != nil {
            throw RegisterError.emailIsAlreadyConnected
        }
    }
    
    func updateUser(on request: Request, userDto: UserDto, userNameNormalized: String) async throws -> User {
        let userFromDb = try await self.get(on: request, userName: userNameNormalized)

        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        user.name = userDto.name
        user.bio = userDto.bio
        user.birthDate = userDto.birthDate
        user.location = userDto.location
        user.website = userDto.website

        try await user.update(on: request.db)
        return user
    }
    
    func deleteUser(on request: Request, userNameNormalized: String) async throws {
        let userFromDb = try await self.get(on: request, userName: userNameNormalized)
        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }
        
        try await user.delete(on: request.db)
    }
    
    func createGravatarHash(from email: String) -> String {
        let gravatarEmail = email.lowercased().trimmingCharacters(in: [" "])

        if let gravatarEmailData = gravatarEmail.data(using: .utf8) {
            return Insecure.MD5.hash(data: gravatarEmailData).hexEncodedString()
        }
        
        return ""
    }
}
