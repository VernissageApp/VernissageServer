//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class TimelinesHashtagActionTests: CustomTestCase {
    
    func testPublicStatusesShouldBeReturnedForUnauthorizedWithoutParams() async throws {

        // Arrange.
        let user = try await User.create(userName: "timredix")
        let (_, attachments) = try await Status.createStatuses(user: user, notePrefix: "Public note #black #white", amount: 4)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            to: "/timelines/hashtag/black?limit=2",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Public note #black #white 4", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Public note #black #white 3", "Second status is not visible.")
    }
    
    func testPublicStatusesShouldBeReturnedForUnauthorizedWithMinId() async throws {

        // Arrange.
        let user = try await User.create(userName: "tomredix")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Min note #red #yellow", amount: 10)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            to: "/timelines/hashtag/red?limit=2&minId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Min note #red #yellow 8", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Min note #red #yellow 7", "Second status is not visible.")
    }
    
    func testPublicStatusesShouldBeReturnedForUnauthorizedWithMaxId() async throws {

        // Arrange.
        let user = try await User.create(userName: "ronredix")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Max note #pink #brown", amount: 10)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            to: "/timelines/hashtag/pink?limit=2&maxId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Max note #pink #brown 5", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Max note #pink #brown 4", "Second status is not visible.")
    }
    
    func testPublicStatusesShouldBeReturnedForUnauthorizedWithSinceId() async throws {

        // Arrange.
        let user = try await User.create(userName: "gregredix")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Since note #gray #blue", amount: 10)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            to: "/timelines/hashtag/blue?limit=20&sinceId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 4, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Since note #gray #blue 10", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Since note #gray #blue 9", "Second status is not visible.")
        XCTAssertEqual(statusesFromApi.data[2].note, "Since note #gray #blue 8", "Third status is not visible.")
        XCTAssertEqual(statusesFromApi.data[3].note, "Since note #gray #blue 7", "Fourth status is not visible.")
    }
}
