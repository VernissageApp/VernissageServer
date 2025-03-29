//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import VaporTesting
import Fluent

extension Application {
    func createUser(userName: String,
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
                       website: String? = nil,
                       manuallyApprovesFollowers: Bool = false,
                       generateKeys: Bool = false,
                       isLocal: Bool = true) async throws -> User {

        
        let (privateKey, publicKey) = generateKeys ? try self.services.cryptoService.generateKeys() : (nil, nil)
        let id = await ApplicationManager.shared.generateId()
        let user = User(id: id,
                        url: "http://localhost:8080/@\(userName)",
                        isLocal: isLocal,
                        userName: userName,
                        account: email ?? "\(userName)@localhost:8080",
                        activityPubProfile: "http://localhost:8080/actors/\(userName)",
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
                        manuallyApprovesFollowers: manuallyApprovesFollowers,
                        forgotPasswordGuid: forgotPasswordGuid,
                        forgotPasswordDate: forgotPasswordDate,
                        bio: bio,
                        isApproved: isApproved)

        _ = try await user.save(on: self.db)
        return user
    }
    
    func getUser(id: Int64, withDeleted: Bool = false) async throws -> User? {
        var query = User.query(on: self.db)
        
        if withDeleted {
            query = query.withDeleted()
        }
        
        return try await query
            .filter(\.$id == id)
            .first()
    }
    
    func getUser(userName: String) async throws -> User {
        guard let user = try await User.query(on: self.db).with(\.$roles).filter(\.$userName == userName).first() else {
            throw SharedApplicationError.unwrap
        }

        return user
    }
    
    func attach(user: User, role: String) async throws {
        guard let roleFromDb = try await self.getRole(code: role) else {
            throw SharedApplicationError.unwrap
        }
        
        let userRoleId = await ApplicationManager.shared.generateId()
        let userRole = try UserRole(id: userRoleId, userId: user.requireID(), roleId: roleFromDb.requireID())
        try await userRole.save(on: self.db)
    }
}
