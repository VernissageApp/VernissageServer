import Vapor
import Fluent

struct CreateAuthClients: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database
            .schema(AuthClient.schema)
            .id()
            .field("type", .string, .required)
            .field("name", .string, .required)
            .field("uri", .string, .required)
            .field("tenantId", .string)
            .field("clientId", .string, .required)
            .field("clientSecret", .string, .required)
            .field("callbackUrl", .string, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .field("deletedAt", .datetime)
            .unique(on: "uri")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(AuthClient.schema).delete()
    }
}
