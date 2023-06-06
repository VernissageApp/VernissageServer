//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

struct CreateUsers: AsyncMigration {
    
    func prepare(on database: Database) async throws {
        try await database
            .schema(User.schema)
            .id()
            .field("isLocal", .bool, .required)
            .field("userName", .string, .required)
            .field("account", .string, .required)
            .field("activityPubProfile", .string, .required)
            .field("email", .string, .required)
            .field("name", .string)
            .field("password", .string, .required)
            .field("salt", .string, .required)
            .field("emailWasConfirmed", .bool, .required)
            .field("isBlocked", .bool, .required)
            .field("emailConfirmationGuid", .string, .required)
            .field("gravatarHash", .string, .required)
            .field("privateKey", .string, .required)
            .field("publicKey", .string, .required)
            .field("forgotPasswordGuid", .string)
            .field("forgotPasswordDate", .datetime)
            .field("bio", .string)
            .field("location", .string)
            .field("website", .string)
            .field("birthDate", .datetime)
            .field("userNameNormalized", .string, .required)
            .field("accountNormalized", .string, .required)
            .field("emailNormalized", .string, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .field("deletedAt", .datetime)
            .unique(on: "userName")
            .unique(on: "account")
            .unique(on: "email")
            .create()
        
        if let sqlDatabase = database as? SQLDatabase {
            try await sqlDatabase
                .create(index: "\(User.schema)_userNameIndex")
                .on("Users")
                .column("userName")
                .run()
            
            try await sqlDatabase
                .create(index: "\(User.schema)_accountIndex")
                .on("Users")
                .column("account")
                .run()
            
            try await sqlDatabase
                .create(index: "\(User.schema)_emailIndex")
                .on("Users")
                .column("email")
                .run()
        }
    }

    func revert(on database: Database) async throws {
        try await database.schema(User.schema).delete()
    }
}
