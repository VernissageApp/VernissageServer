import Vapor
import Fluent

struct CreateEvents: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database
            .schema(Event.schema)
            .id()
            .field("type", .string, .required)
            .field("method", .string, .required)
            .field("uri", .string, .required)
            .field("wasSuccess", .bool, .required)
            .field("userId", .uuid)
            .field("requestBody", .string)
            .field("responseBody", .string)
            .field("error", .string)
            .field("createdAt", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Event.schema).delete()
    }
}
