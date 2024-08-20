//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class BookmarksListActionTests: CustomTestCase {
    
    func testStatusesShouldNotBeReturnedForUnauthorizedUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "gregfoko")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Bookmarked note", amount: 4)
        _ = try await StatusBookmark.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/bookmarks?limit=2",
            method: .GET
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testStatusesShouldBeReturnedWithoutParams() async throws {

        // Arrange.
        let user = try await User.create(userName: "timfoko")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Bookmarked note", amount: 4)
        _ = try await StatusBookmark.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "timfoko", password: "p@ssword"),
            to: "/bookmarks?limit=2",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Bookmarked note 4", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Bookmarked note 3", "Second status is not visible.")
    }
    
    func testStatusesShouldBeReturnedWithMinId() async throws {

        // Arrange.
        let user = try await User.create(userName: "trondfoko")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Min bookmarked note", amount: 10)
        let bookmarkedStatuses = try await StatusBookmark.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "trondfoko", password: "p@ssword"),
            to: "/bookmarks?limit=2&minId=\(bookmarkedStatuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Min bookmarked note 8", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Min bookmarked note 7", "Second status is not visible.")
    }
    
    func testStatusesShouldBeReturnedWithMaxId() async throws {

        // Arrange.
        let user = try await User.create(userName: "rickfoko")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Max bookmarked note", amount: 10)
        let bookmarkedStatuses = try await StatusBookmark.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "rickfoko", password: "p@ssword"),
            to: "/bookmarks?limit=2&maxId=\(bookmarkedStatuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 2, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Max bookmarked note 5", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Max bookmarked note 4", "Second status is not visible.")
    }
    
    func testStatusesShouldBeReturnedWithSinceId() async throws {

        // Arrange.
        let user = try await User.create(userName: "benfoko")
        let (statuses, attachments) = try await Status.createStatuses(user: user, notePrefix: "Since bookmarked note", amount: 10)
        let bookmarkedStatuses = try await StatusBookmark.create(user: user, statuses: statuses)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try SharedApplication.application().getResponse(
            as: .user(userName: "benfoko", password: "p@ssword"),
            to: "/bookmarks?limit=20&sinceId=\(bookmarkedStatuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        XCTAssertEqual(statusesFromApi.data.count, 4, "Statuses list should be returned.")
        XCTAssertEqual(statusesFromApi.data[0].note, "Since bookmarked note 10", "First status is not visible.")
        XCTAssertEqual(statusesFromApi.data[1].note, "Since bookmarked note 9", "Second status is not visible.")
        XCTAssertEqual(statusesFromApi.data[2].note, "Since bookmarked note 8", "Third status is not visible.")
        XCTAssertEqual(statusesFromApi.data[3].note, "Since bookmarked note 7", "Fourth status is not visible.")
    }
}
