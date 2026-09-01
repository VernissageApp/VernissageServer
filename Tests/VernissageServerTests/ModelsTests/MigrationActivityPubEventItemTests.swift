//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Testing

struct MigrationActivityPubEventItemTests {
    @Test(
        "Event id aliases should fit PostgreSQL identifier limit",
        arguments: [
            "\(MigrationFollowActivityPubEventItem.schema)_\(MigrationFollowActivityPubEventItem().$migrationFollowActivityPubEvent.$id.key)",
            "\(MigrationMoveActivityPubEventItem.schema)_\(MigrationMoveActivityPubEventItem().$migrationMoveActivityPubEvent.$id.key)"
        ]
    )
    func eventIdAliasFitsPostgreSQLIdentifierLimit(alias: String) {
        #expect(alias.utf8.count <= 63, "PostgreSQL truncates identifiers longer than 63 bytes.")
    }
}
