import Vapor
import Fluent

struct CreateUserRoles: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserRole.schema)
            .id()
            .field("userId", .uuid, .required, .references("Users", "id"))
            .field("roleId", .uuid, .required, .references("Roles", "id"))
            .field("createdAt", .datetime)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserRole.schema).delete()
    }
}
