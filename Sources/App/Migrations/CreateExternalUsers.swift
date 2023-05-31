import Vapor
import Fluent

struct CreateExternalUsers: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database
            .schema(ExternalUser.schema)
            .id()
            .field("type", .string, .required)
            .field("externalId", .string, .required)
            .field("authenticationToken", .string)
            .field("tokenCreatedAt", .datetime)
            .field("userId", .uuid, .references("Users", "id"))
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ExternalUser.schema).delete()
    }
}
