//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTVapor
import Fluent

extension User {
    static func create(userName: String,
                       email: String? = nil,
                       name: String? = nil,
                       password: String = "83427d87b9492b7e048a975025190efa55edb9948ae7ced5c6ccf1a553ce0e2b",
                       salt: String = "TNhZYL4F66KY7fUuqS/Juw==",
                       emailWasConfirmed: Bool = true,
                       isBlocked: Bool = false,
                       isApproved: Bool = true,
                       emailConfirmationGuid: String? = nil,
                       gravatarHash: String = "",
                       forgotPasswordGuid: String? = nil,
                       forgotPasswordDate: Date? = nil,
                       bio: String? = nil,
                       location: String? = nil,
                       website: String? = nil) async throws -> User {

        let (privateKey, publicKey) = try SharedApplication.application().services.cryptoService.generateKeys()
        let user = User(isLocal: true,
                        userName: userName,
                        account: email ?? "\(userName)@localhost:8000",
                        activityPubProfile: "http://localhost:8000/actors/\(userName)",
                        email: email ?? "\(userName)@testemail.com",
                        name: name ?? userName,
                        password: password,
                        salt: salt,
                        emailWasConfirmed: emailWasConfirmed,
                        isBlocked: isBlocked,
                        locale: "en_US",
                        emailConfirmationGuid: emailConfirmationGuid,
                        gravatarHash: gravatarHash,
                        privateKey: privateKey,
                        publicKey: publicKey,
                        forgotPasswordGuid: forgotPasswordGuid,
                        forgotPasswordDate: forgotPasswordDate,
                        bio: bio,
                        isApproved: isApproved)

        _ = try await user.save(on: SharedApplication.application().db)

        return user
    }
    
    static func get(userName: String) async throws -> User {
        guard let user = try await User.query(on: SharedApplication.application().db).with(\.$roles).filter(\.$userName == userName).first() else {
            throw SharedApplicationError.unwrap
        }

        return user
    }
    
    func attach(role: String) async throws {
        let roleFromDb = try await Role.get(code: role)
        try await self.$roles.attach(roleFromDb, on: SharedApplication.application().db)
    }
}
