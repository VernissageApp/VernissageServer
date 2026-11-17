//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent
import FluentSQLiteDriver
import SQLKit
import Testing

struct DeletedUserDetailsMigrationTests {
    private struct UserDetailsRow: Decodable {
        let id: Int64
        let email: String?
        let emailNormalized: String?
        let name: String?
        let bio: String?
        let reason: String?
        let queryNormalized: String
    }

    @Test
    func `Migration should clear only deleted local account contact and profile details`() async throws {

        // Arrange.
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        do {
            let database = app.db
            let sql = try #require(database as? SQLDatabase)
            try await database.schema(User.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("isLocal", .bool, .required)
                .field("email", .string)
                .field("emailNormalized", .string)
                .field("name", .string)
                .field("bio", .string)
                .field("reason", .string)
                .field("queryNormalized", .string, .required)
                .field("deletedAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "email")
                .create()

            for (id, isLocal, deleted) in [(Int64(1), true, true), (2, true, false), (3, false, true), (4, true, true)] {
                let email: String? = id == 4 ? nil : "user\(id)@example.com"
                let deletedAt: Date? = deleted ? Date() : nil
                let name: String? = id == 4 ? nil : "Name \(id)"
                let bio: String? = id == 4 ? nil : "Bio \(id)"
                let reason: String? = id == 4 ? nil : "Reason \(id)"
                let queryNormalized = id == 4 ? "" : "NAME \(id) USER\(id)"
                try await sql.insert(into: User.schema)
                    .columns("id", "isLocal", "email", "emailNormalized", "name", "bio", "reason", "queryNormalized", "deletedAt")
                    .values(id, isLocal, email, email?.uppercased(), name, bio, reason, queryNormalized, deletedAt)
                    .run()
            }

            // Act.
            try await User.ClearDeletedLocalUserDetails().prepare(on: database)
            try await User.ClearDeletedLocalUserDetails().prepare(on: database)

            // Assert.
            let rows = try await sql.select()
                .columns("id", "email", "emailNormalized", "name", "bio", "reason", "queryNormalized")
                .from(User.schema).orderBy("id").all(decoding: UserDetailsRow.self)
            #expect(rows.count == 4)
            let deletedLocal = try #require(rows.first { $0.id == 1 })
            #expect(deletedLocal.email == nil)
            #expect(deletedLocal.emailNormalized == nil)
            #expect(deletedLocal.name == nil)
            #expect(deletedLocal.bio == nil)
            #expect(deletedLocal.reason == nil)
            #expect(deletedLocal.queryNormalized == "")
            for id in [Int64(2), 3] {
                let row = try #require(rows.first { $0.id == id })
                #expect(row.email == "user\(id)@example.com")
                #expect(row.emailNormalized == "USER\(id)@EXAMPLE.COM")
                #expect(row.name == "Name \(id)")
                #expect(row.bio == "Bio \(id)")
                #expect(row.reason == "Reason \(id)")
                #expect(row.queryNormalized == "NAME \(id) USER\(id)")
            }
            let withoutEmail = try #require(rows.first { $0.id == 4 })
            #expect(withoutEmail.email == nil)
            #expect(withoutEmail.emailNormalized == nil)
            #expect(withoutEmail.name == nil)
            #expect(withoutEmail.bio == nil)
            #expect(withoutEmail.reason == nil)
            #expect(withoutEmail.queryNormalized == "")
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }
}
