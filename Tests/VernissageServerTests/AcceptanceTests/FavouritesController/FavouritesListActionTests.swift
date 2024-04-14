//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class FavouritesListActionTests: CustomTestCase {
    
    func testStatusesShouldNotBeReturnedForUnauthorizedUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "gregwuro")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Favourited note", amount: 4)
        _ = try await StatusFavourite.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/favourites?limit=2",
            method: .GET
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testStatusesShouldBeReturnedWithoutParams() async throws {

        // Arrange.
        let user = try await User.create(userName: "timwuro")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Favourited note", amount: 4)
        _ = try await StatusFavourite.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "timwuro", password: "p@ssword"),
            to: "/favourites?limit=2",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Favourited note 4", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Favourited note 3", "Second status is not visible.")
    }
    
    func testStatusesShouldBeReturnedWithMinId() async throws {

        // Arrange.
        let user = try await User.create(userName: "trondwuro")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Min favourited note", amount: 10)
        let favouritedStatuses = try await StatusFavourite.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "trondwuro", password: "p@ssword"),
            to: "/favourites?limit=2&minId=\(favouritedStatuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Min favourited note 8", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Min favourited note 7", "Second status is not visible.")
    }
    
    func testStatusesShouldBeReturnedWithMaxId() async throws {

        // Arrange.
        let user = try await User.create(userName: "rickwuro")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Max favourited note", amount: 10)
        let favouritedStatuses = try await StatusFavourite.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "rickwuro", password: "p@ssword"),
            to: "/favourites?limit=2&maxId=\(favouritedStatuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Max favourited note 5", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Max favourited note 4", "Second status is not visible.")
    }
    
    func testStatusesShouldBeReturnedWithSinceId() async throws {

        // Arrange.
        let user = try await User.create(userName: "benwuro")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Since favourited note", amount: 10)
        let favouritedStatuses = try await StatusFavourite.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "benwuro", password: "p@ssword"),
            to: "/favourites?limit=20&sinceId=\(favouritedStatuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 4, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Since favourited note 10", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Since favourited note 9", "Second status is not visible.")
        XCTAssertEqual(statusesFromApi.data[2].note, "Since favourited note 8", "Third status is not visible.")
        XCTAssertEqual(statusesFromApi.data[3].note, "Since favourited note 7", "Fourth status is not visible.")
    }
}
