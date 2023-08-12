//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension User {
    struct CreateUsers: AsyncMigration {
        
        func prepare(on database: Database) async throws {
            try await database
                .schema(User.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("isLocal", .bool, .required)
                .field("userName", .varchar(50), .required)
                .field("account", .string, .required)
                .field("activityPubProfile", .string, .required)
                .field("email", .string)
                .field("name", .varchar(100))
                .field("password", .varchar(100))
                .field("salt", .varchar(100))
                .field("emailWasConfirmed", .bool)
                .field("isBlocked", .bool, .required)
                .field("isApproved", .bool, .required)
                .field("locale", .varchar(5), .required)
                .field("emailConfirmationGuid", .string)
                .field("gravatarHash", .string)
                .field("privateKey", .string)
                .field("publicKey", .string)
                .field("manuallyApprovesFollowers", .bool)
                .field("forgotPasswordGuid", .varchar(100))
                .field("forgotPasswordDate", .datetime)
                .field("bio", .varchar(500))
                .field("userNameNormalized", .varchar(50), .required)
                .field("accountNormalized", .string, .required)
                .field("emailNormalized", .string)
                .field("activityPubProfileNormalized", .string, .required)
                .field("avatarFileName", .varchar(100))
                .field("reason", .varchar(500))
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
                    .on(User.schema)
                    .column("userNameNormalized")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(User.schema)_accountIndex")
                    .on(User.schema)
                    .column("accountNormalized")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(User.schema)_emailIndex")
                    .on(User.schema)
                    .column("emailNormalized")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(User.schema)_activityPubProfileIndex")
                    .on(User.schema)
                    .column("activityPubProfileNormalized")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(User.schema).delete()
        }
    }
    
    struct UsersHeaderField: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(User.schema)
                .field("headerFileName", .string)
                .update()
            
            try await database
                .schema(User.schema)
                .field("statusesCount", .int, .required, .sql(.default(0)))
                .update()
            
            try await database
                .schema(User.schema)
                .field("followersCount", .int, .required, .sql(.default(0)))
                .update()
            try await database
                .schema(User.schema)
                .field("followingCount", .int, .required, .sql(.default(0)))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(User.schema)
                .deleteField("headerFileName")
                .update()
            
            try await database
                .schema(User.schema)
                .deleteField("statusesCount")
                .update()
            
            try await database
                .schema(User.schema)
                .deleteField("followersCount")
                .update()
            
            try await database
                .schema(User.schema)
                .deleteField("followingCount")
                .update()
        }
    }
    
    struct AddSharedInboxUrl: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(User.schema)
                .field("sharedInbox", .string)
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(User.schema)
                .deleteField("sharedInbox")
                .update()
        }
    }
    
    struct AddUserInboxUrl: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(User.schema)
                .field("userInbox", .string)
                .update()
            
            try await database
                .schema(User.schema)
                .field("userOutbox", .string)
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(User.schema)
                .deleteField("userInbox")
                .update()
            
            try await database
                .schema(User.schema)
                .deleteField("userOutbox")
                .update()
        }
    }
}
