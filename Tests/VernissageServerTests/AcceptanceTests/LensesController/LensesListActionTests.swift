//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Fluent
import Testing
import Vapor

extension ControllersTests {

    @Suite("Lenses (GET /lenses)", .serialized, .tags(.lenses))
    struct LensesListActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Lenses should be paginated and sorted by amount descending`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "lenseslist")

            let firstLens = Lens(
                id: application.services.snowflakeService.generate(),
                name: "Lens list first",
                amount: 2_000_000_003
            )
            let secondLens = Lens(
                id: application.services.snowflakeService.generate(),
                name: "Lens list second",
                amount: 2_000_000_002
            )
            let thirdLens = Lens(
                id: application.services.snowflakeService.generate(),
                name: "Lens list third",
                amount: 2_000_000_001
            )
            try await [firstLens, secondLens, thirdLens].create(on: application.db)

            // Act.
            let lenses = try await application.getResponse(
                as: .user(userName: "lenseslist", password: "p@ssword"),
                to: "/lenses?page=1&size=2",
                method: .GET,
                decodeTo: PaginableResultDto<LensDto>.self
            )

            // Assert.
            #expect(lenses.data.map(\.name) == ["Lens list first", "Lens list second"])
            #expect(lenses.data.map(\.amount) == [2_000_000_003, 2_000_000_002])
            #expect(lenses.page == 1)
            #expect(lenses.size == 2)
            #expect(lenses.total >= 3)

            try await Lens.query(on: application.db)
                .filter(\.$name ~~ ["Lens list first", "Lens list second", "Lens list third"])
                .delete()
        }

        @Test
        func `Lenses should be filtered by normalized name prefix`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "lensesquery")

            let matchingLens = Lens(
                id: application.services.snowflakeService.generate(),
                name: "Lens query matching"
            )
            let nonMatchingLens = Lens(
                id: application.services.snowflakeService.generate(),
                name: "Other lens query matching"
            )
            try await [matchingLens, nonMatchingLens].create(on: application.db)

            // Act.
            let lenses = try await application.getResponse(
                as: .user(userName: "lensesquery", password: "p@ssword"),
                to: "/lenses?query=lens%20query",
                method: .GET,
                decodeTo: PaginableResultDto<LensDto>.self
            )

            // Assert.
            #expect(lenses.data.map(\.name) == ["Lens query matching"])
            #expect(lenses.total == 1)

            try await Lens.query(on: application.db)
                .filter(\.$name ~~ ["Lens query matching", "Other lens query matching"])
                .delete()
        }

        @Test
        func `Anonymous access should depend on lenses setting`() async throws {
            // Arrange.
            try await application.updateSetting(key: .showLensesForAnonymous, value: .boolean(false))

            // Act.
            let disabledResponse = try await application.sendRequest(to: "/lenses", method: .GET)

            try await application.updateSetting(key: .showLensesForAnonymous, value: .boolean(true))
            let enabledResponse = try await application.sendRequest(to: "/lenses", method: .GET)

            // Assert.
            #expect(disabledResponse.status == .unauthorized)
            #expect(enabledResponse.status == .ok)
        }
    }
}
