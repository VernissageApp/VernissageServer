//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class TimelinesFeaturedActionTests: CustomTestCase {
        
    func testStatusesShouldBeReturnedWithoutParams() async throws {

        // Arrange.
        try await Setting.update(key: .showEditorsChoiceForAnonymous, value: .boolean(true))

        let user = try await User.create(userName: "timastonix")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Public note", amount: 4)
        _ = try await FeaturedStatus.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "timastonix", password: "p@ssword"),
            to: "/timelines/featured?limit=2",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Public note 4", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Public note 3", "Second status is not visible.")
    }
    
    func testStatusesShouldBeReturnedWithMinId() async throws {

        // Arrange.
        try await Setting.update(key: .showEditorsChoiceForAnonymous, value: .boolean(true))

        let user = try await User.create(userName: "trondastonix")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Min note", amount: 10)
        let featuredStatuses = try await FeaturedStatus.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "trondastonix", password: "p@ssword"),
            to: "/timelines/featured?limit=2&minId=\(featuredStatuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Min note 8", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Min note 7", "Second status is not visible.")
    }
    
    func testStatusesShouldBeReturnedWithMaxId() async throws {

        // Arrange.
        try await Setting.update(key: .showEditorsChoiceForAnonymous, value: .boolean(true))

        let user = try await User.create(userName: "rickastonix")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Max note", amount: 10)
        let featuredStatuses = try await FeaturedStatus.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "rickastonix", password: "p@ssword"),
            to: "/timelines/featured?limit=2&maxId=\(featuredStatuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Max note 5", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Max note 4", "Second status is not visible.")
    }
    
    func testStatusesShouldBeReturnedWithSinceId() async throws {

        // Arrange.
        try await Setting.update(key: .showEditorsChoiceForAnonymous, value: .boolean(true))

        let user = try await User.create(userName: "benastonix")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Since note", amount: 10)
        let featuredStatuses = try await FeaturedStatus.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "benastonix", password: "p@ssword"),
            to: "/timelines/featured?limit=20&sinceId=\(featuredStatuses[5].id!)",
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
    
    func testStatusesShouldNotBeReturnedWhenPublicAccessIsDisabled() async throws {
        // Arrange.
        try await Setting.update(key: .showEditorsChoiceForAnonymous, value: .boolean(false))
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/timelines/featured?limit=2",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
