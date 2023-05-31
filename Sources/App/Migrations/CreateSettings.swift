import Vapor
import Fluent

struct CreateSettings: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database
            .schema(Setting.schema)
            .id()
            .field("key", .string, .required)
            .field("value", .string, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .unique(on: "key")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Setting.schema).delete()
    }
}
