import Vapor
import Fluent

struct AddSvgIconToAuthClient: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database
            .schema(AuthClient.schema)
            .field("svgIcon", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(AuthClient.schema).deleteField("svgIcon").update()
    }
}
