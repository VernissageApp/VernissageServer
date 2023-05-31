import Vapor
import Fluent

struct CreateRoles: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database
            .schema(Role.schema)
            .id()
            .field("code", .string, .required)
            .field("title", .string, .required)
            .field("description", .string)
            .field("hasSuperPrivileges", .bool, .required)
            .field("isDefault", .bool, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .field("deletedAt", .datetime)
            .unique(on: "code")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Role.schema).delete()
    }
}
