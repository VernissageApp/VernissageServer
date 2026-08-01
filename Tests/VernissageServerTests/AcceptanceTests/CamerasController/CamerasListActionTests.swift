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

    @Suite("Cameras (GET /cameras)", .serialized, .tags(.cameras))
    struct CamerasListActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Cameras should be paginated and sorted by amount descending`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "cameraslist")

            let firstCamera = Camera(
                id: application.services.snowflakeService.generate(),
                name: "Camera list first",
                amount: 2_000_000_003
            )
            let secondCamera = Camera(
                id: application.services.snowflakeService.generate(),
                name: "Camera list second",
                amount: 2_000_000_002
            )
            let thirdCamera = Camera(
                id: application.services.snowflakeService.generate(),
                name: "Camera list third",
                amount: 2_000_000_001
            )
            try await [firstCamera, secondCamera, thirdCamera].create(on: application.db)

            // Act.
            let cameras = try await application.getResponse(
                as: .user(userName: "cameraslist", password: "p@ssword"),
                to: "/cameras?page=1&size=2",
                method: .GET,
                decodeTo: PaginableResultDto<CameraDto>.self
            )

            // Assert.
            #expect(cameras.data.map(\.name) == ["Camera list first", "Camera list second"])
            #expect(cameras.data.map(\.amount) == [2_000_000_003, 2_000_000_002])
            #expect(cameras.page == 1)
            #expect(cameras.size == 2)
            #expect(cameras.total >= 3)

            try await Camera.query(on: application.db)
                .filter(\.$name ~~ ["Camera list first", "Camera list second", "Camera list third"])
                .delete()
        }

        @Test
        func `Cameras should be filtered by normalized name prefix`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "camerasquery")

            let matchingCamera = Camera(
                id: application.services.snowflakeService.generate(),
                name: "Camera query matching"
            )
            let nonMatchingCamera = Camera(
                id: application.services.snowflakeService.generate(),
                name: "Other camera query matching"
            )
            try await [matchingCamera, nonMatchingCamera].create(on: application.db)

            // Act.
            let cameras = try await application.getResponse(
                as: .user(userName: "camerasquery", password: "p@ssword"),
                to: "/cameras?query=camera%20query",
                method: .GET,
                decodeTo: PaginableResultDto<CameraDto>.self
            )

            // Assert.
            #expect(cameras.data.map(\.name) == ["Camera query matching"])
            #expect(cameras.total == 1)

            try await Camera.query(on: application.db)
                .filter(\.$name ~~ ["Camera query matching", "Other camera query matching"])
                .delete()
        }

        @Test
        func `Anonymous access should depend on cameras setting`() async throws {
            // Arrange.
            try await application.updateSetting(key: .showCamerasForAnonymous, value: .boolean(false))

            // Act.
            let disabledResponse = try await application.sendRequest(to: "/cameras", method: .GET)

            try await application.updateSetting(key: .showCamerasForAnonymous, value: .boolean(true))
            let enabledResponse = try await application.sendRequest(to: "/cameras", method: .GET)

            // Assert.
            #expect(disabledResponse.status == .unauthorized)
            #expect(enabledResponse.status == .ok)
        }
    }
}
