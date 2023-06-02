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
                       emailConfirmationGuid: String = "",
                       gravatarHash: String = "",
                       forgotPasswordGuid: String? = nil,
                       forgotPasswordDate: Date? = nil,
                       bio: String? = nil,
                       location: String? = nil,
                       website: String? = nil,
                       birthDate: Date? = nil) throws -> User {

        
        let user = User(userName: userName,
                        account: email ?? "\(userName)@host.com",
                        activityPubProfile: "http://host.com/actors/\(userName)",
                        email: email ?? "\(userName)@testemail.com",
                        name: name ?? userName,
                        password: password,
                        salt: salt,
                        emailWasConfirmed: emailWasConfirmed,
                        isBlocked: isBlocked,
                        emailConfirmationGuid: emailConfirmationGuid,
                        gravatarHash: gravatarHash,
                        privateKey: "",
                        publicKey: "",
                        forgotPasswordGuid: forgotPasswordGuid,
                        forgotPasswordDate: forgotPasswordDate,
                        bio: bio,
                        location: location,
                        website: website,
                        birthDate: birthDate)

        _ = try user.save(on: SharedApplication.application().db).wait()

        return user
    }
    
    static func get(userName: String) throws -> User {
        guard let user = try User.query(on: SharedApplication.application().db).with(\.$roles).filter(\.$userName == userName).first().wait() else {
            throw SharedApplicationError.unwrap
        }

        return user
    }
    
    func attach(role: String) throws {
        let roleFromDb = try Role.get(code: role)
        try self.$roles.attach(roleFromDb, on: SharedApplication.application().db).wait()
    }
}
