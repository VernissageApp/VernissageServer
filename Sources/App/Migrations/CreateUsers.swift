import Vapor
import Fluent

struct CreateUsers: Migration {
    
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database
            .schema(User.schema)
            .id()
            .field("userName", .string, .required)
            .field("email", .string, .required)
            .field("name", .string)
            .field("password", .string, .required)
            .field("salt", .string, .required)
            .field("emailWasConfirmed", .bool, .required)
            .field("isBlocked", .bool, .required)
            .field("emailConfirmationGuid", .string, .required)
            .field("gravatarHash", .string, .required)
            .field("forgotPasswordGuid", .string)
            .field("forgotPasswordDate", .datetime)
            .field("bio", .string)
            .field("location", .string)
            .field("website", .string)
            .field("birthDate", .datetime)
            .field("userNameNormalized", .string, .required)
            .field("emailNormalized", .string, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .field("deletedAt", .datetime)
            .unique(on: "userName")
            .unique(on: "email")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema).delete()
    }
}
