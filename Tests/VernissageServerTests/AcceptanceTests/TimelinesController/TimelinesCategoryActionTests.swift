//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class TimelinesCategoryActionTests: CustomTestCase {
    
    func testPublicStatusesShouldBeReturnedForUnauthorizedWithoutParams() async throws {

        // Arrange.
        let user = try await User.create(userName: "timfucher")
        let category1 = try await Category.get(name: "Abstract")!
        let category2 = try await Category.get(name: "Nature")!
        let (_, attachments1) = try await Status.createStatuses(user: user,
                                                               notePrefix: "Category abstract note",
                                                               categoryId: category1.stringId()!,
                                                               amount: 4)
        
        let (_, attachments2) = try await Status.createStatuses(user: user,
                                                               notePrefix: "Category nature note",
                                                               categoryId: category2.stringId()!,
                                                               amount: 4)

        defer {
            Status.clearFiles(attachments: attachments1)
            Status.clearFiles(attachments: attachments2)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            to: "/timelines/category/\(category1.name.lowercased())?limit=2",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Category abstract note 4", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Category abstract note 3", "Second status is not visible.")
    }
    
    func testPublicStatusesShouldBeReturnedForUnauthorizedWithMinId() async throws {

        // Arrange.
        let user = try await User.create(userName: "tomfucher")
        let category = try await Category.get(name: "Still Life")!
        let (statuses, attachments) = try await Status.createStatuses(user: user,
                                                               notePrefix: "Category note",
                                                               categoryId: category.stringId()!,
                                                               amount: 10)
        
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            to: "/timelines/category/still%20life?limit=2&minId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Category note 8", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Category note 7", "Second status is not visible.")
    }
    
    func testPublicStatusesShouldBeReturnedForUnauthorizedWithMaxId() async throws {

        // Arrange.
        let user = try await User.create(userName: "ronfucher")
        let category = try await Category.get(name: "Abstract")!
        let (statuses, attachments) = try await Status.createStatuses(user: user,
                                                               notePrefix: "Category note",
                                                               categoryId: category.stringId()!,
                                                               amount: 10)

        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            to: "/timelines/category/\(category.name.lowercased())?limit=2&maxId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Category note 5", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Category note 4", "Second status is not visible.")
    }
    
    func testPublicStatusesShouldBeReturnedForUnauthorizedWithSinceId() async throws {

        // Arrange.
        let user = try await User.create(userName: "gregfucher")
        let category = try await Category.get(name: "Abstract")!
        let (statuses, attachments) = try await Status.createStatuses(user: user,
                                                               notePrefix: "Category note",
                                                               categoryId: category.stringId()!,
                                                               amount: 10)
        
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            to: "/timelines/category/\(category.name.lowercased())?limit=20&sinceId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 4, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Category note 10", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Category note 9", "Second status is not visible.")
        XCTAssertEqual(statusesFromApi.data[2].note, "Category note 8", "Third status is not visible.")
        XCTAssertEqual(statusesFromApi.data[3].note, "Category note 7", "Fourth status is not visible.")
    }
}
