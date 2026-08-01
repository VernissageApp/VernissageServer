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

    @Suite("Films (GET /films)", .serialized, .tags(.films))
    struct FilmsListActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Films should be paginated and sorted by amount descending`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "filmslist")

            let firstFilm = Film(
                id: application.services.snowflakeService.generate(),
                name: "Film list first",
                amount: 2_000_000_003
            )
            let secondFilm = Film(
                id: application.services.snowflakeService.generate(),
                name: "Film list second",
                amount: 2_000_000_002
            )
            let thirdFilm = Film(
                id: application.services.snowflakeService.generate(),
                name: "Film list third",
                amount: 2_000_000_001
            )
            try await [firstFilm, secondFilm, thirdFilm].create(on: application.db)

            // Act.
            let films = try await application.getResponse(
                as: .user(userName: "filmslist", password: "p@ssword"),
                to: "/films?page=1&size=2",
                method: .GET,
                decodeTo: PaginableResultDto<FilmDto>.self
            )

            // Assert.
            #expect(films.data.map(\.name) == ["Film list first", "Film list second"])
            #expect(films.data.map(\.amount) == [2_000_000_003, 2_000_000_002])
            #expect(films.page == 1)
            #expect(films.size == 2)
            #expect(films.total >= 3)

            try await Film.query(on: application.db)
                .filter(\.$name ~~ ["Film list first", "Film list second", "Film list third"])
                .delete()
        }

        @Test
        func `Films should be filtered by normalized name prefix`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "filmsquery")

            let matchingFilm = Film(
                id: application.services.snowflakeService.generate(),
                name: "Film query matching"
            )
            let nonMatchingFilm = Film(
                id: application.services.snowflakeService.generate(),
                name: "Other film query matching"
            )
            try await [matchingFilm, nonMatchingFilm].create(on: application.db)

            // Act.
            let films = try await application.getResponse(
                as: .user(userName: "filmsquery", password: "p@ssword"),
                to: "/films?query=film%20query",
                method: .GET,
                decodeTo: PaginableResultDto<FilmDto>.self
            )

            // Assert.
            #expect(films.data.map(\.name) == ["Film query matching"])
            #expect(films.total == 1)

            try await Film.query(on: application.db)
                .filter(\.$name ~~ ["Film query matching", "Other film query matching"])
                .delete()
        }

        @Test
        func `Anonymous access should depend on films setting`() async throws {
            // Arrange.
            try await application.updateSetting(key: .showFilmsForAnonymous, value: .boolean(false))

            // Act.
            let disabledResponse = try await application.sendRequest(to: "/films", method: .GET)

            try await application.updateSetting(key: .showFilmsForAnonymous, value: .boolean(true))
            let enabledResponse = try await application.sendRequest(to: "/films", method: .GET)

            // Assert.
            #expect(disabledResponse.status == .unauthorized)
            #expect(enabledResponse.status == .ok)
        }
    }
}
