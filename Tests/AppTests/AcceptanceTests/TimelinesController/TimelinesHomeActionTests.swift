//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class TimelinesHomeActionTests: CustomTestCase {
    
    func testStatusesShouldNotBeReturnedForUnauthorizedUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "gregfoba")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Public note", amount: 4)
        try await UserStatus.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/timelines/home?limit=2",
            method: .GET
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testStatusesShouldBeReturnedWithoutParams() async throws {

        // Arrange.
        let user = try await User.create(userName: "timfoba")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Public note", amount: 4)
        try await UserStatus.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "timfoba", password: "p@ssword"),
            to: "/timelines/home?limit=2",
            method: .GET,
            decodeTo: [StatusDto].self
        )
        
        // Assert.
        XCTAssert(statusesFromApi.count == 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi[0].note, "Public note 4", "First status is not visible.")
        XCTAssertEqual(statusesFromApi[1].note, "Public note 3", "Second status is not visible.")
    }
    
    func testStatusesShouldBeReturnedWithMinId() async throws {

        // Arrange.
        let user = try await User.create(userName: "trondfoba")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Min note", amount: 10)
        try await UserStatus.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "trondfoba", password: "p@ssword"),
            to: "/timelines/home?limit=2&minId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: [StatusDto].self
        )
        
        // Assert.
        XCTAssert(statusesFromApi.count == 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi[0].note, "Min note 8", "First status is not visible.")
        XCTAssertEqual(statusesFromApi[1].note, "Min note 7", "Second status is not visible.")
    }
    
    func testStatusesShouldBeReturnedWithMaxId() async throws {

        // Arrange.
        let user = try await User.create(userName: "rickfoba")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Max note", amount: 10)
        try await UserStatus.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "rickfoba", password: "p@ssword"),
            to: "/timelines/home?limit=2&maxId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: [StatusDto].self
        )
        
        // Assert.
        XCTAssert(statusesFromApi.count == 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi[0].note, "Max note 5", "First status is not visible.")
        XCTAssertEqual(statusesFromApi[1].note, "Max note 4", "Second status is not visible.")
    }
    
    func testStatusesShouldBeReturnedWithSinceId() async throws {

        // Arrange.
        let user = try await User.create(userName: "benfoba")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Since note", amount: 10)
        try await UserStatus.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "benfoba", password: "p@ssword"),
            to: "/timelines/home?limit=20&sinceId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: [StatusDto].self
        )
        
        // Assert.
        XCTAssert(statusesFromApi.count == 4, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi[0].note, "Since note 10", "First status is not visible.")
        XCTAssertEqual(statusesFromApi[1].note, "Since note 9", "Second status is not visible.")
        XCTAssertEqual(statusesFromApi[2].note, "Since note 8", "Second status is not visible.")
        XCTAssertEqual(statusesFromApi[3].note, "Since note 7", "Second status is not visible.")
    }
}
