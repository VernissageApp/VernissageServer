//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class TimelinesPublicActionTests: CustomTestCase {
    
    func testPublicStatusesShouldBeReturnedForUnauthorizedWithoutParams() async throws {

        // Arrange.
        let user = try await User.create(userName: "timpinq")
        let (_, attachments) = try await Status.createStatuses(user: user, notePrefix: "Public note", amount: 4)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            to: "/timelines/public?limit=2",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Public note 4", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Public note 3", "Second status is not visible.")
    }
    
    func testPublicStatusesShouldBeReturnedForUnauthorizedWithMinId() async throws {

        // Arrange.
        let user = try await User.create(userName: "tompinq")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Min note", amount: 10)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            to: "/timelines/public?limit=2&minId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Min note 8", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Min note 7", "Second status is not visible.")
    }
    
    func testPublicStatusesShouldBeReturnedForUnauthorizedWithMaxId() async throws {

        // Arrange.
        let user = try await User.create(userName: "ronpinq")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Max note", amount: 10)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            to: "/timelines/public?limit=2&maxId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Max note 5", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Max note 4", "Second status is not visible.")
    }
    
    func testPublicStatusesShouldBeReturnedForUnauthorizedWithSinceId() async throws {

        // Arrange.
        let user = try await User.create(userName: "gregpinq")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Since note", amount: 10)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            to: "/timelines/public?limit=20&sinceId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 4, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Since note 10", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Since note 9", "Second status is not visible.")
        XCTAssertEqual(statusesFromApi.data[2].note, "Since note 8", "Third status is not visible.")
        XCTAssertEqual(statusesFromApi.data[3].note, "Since note 7", "Fourth status is not visible.")
    }
}
