//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

@Suite("GET /home", .serialized, .tags(.timelines))
struct TimelinesHomeActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Statuses should not be returned for unauthorized user")
    func statusesShouldNotBeReturnedForUnauthorizedUser() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "gregfoba")
        let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Public note", amount: 4)
        _ = try await application.createUserStatus(type: .owner, user: user, statuses: statuses)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let response = try application.sendRequest(
            to: "/timelines/home?limit=2",
            method: .GET
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    @Test("Statuses should be returned without params")
    func statusesShouldBeReturnedWithoutParams() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "timfoba")
        let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Public note", amount: 4)
        _ = try await application.createUserStatus(type: .owner, user: user, statuses: statuses)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try application.getResponse(
            as: .user(userName: "timfoba", password: "p@ssword"),
            to: "/timelines/home?limit=2",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
        #expect(statusesFromApi.data[0].note == "Public note 4", "First status is not visible.")
        #expect(statusesFromApi.data[1].note == "Public note 3", "Second status is not visible.")
    }
    
    @Test("Statuses should be returned with minId")
    func statusesShouldBeReturnedWithMinId() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "trondfoba")
        let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Min note", amount: 10)
        let userStatuses = try await application.createUserStatus(type: .owner, user: user, statuses: statuses)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try application.getResponse(
            as: .user(userName: "trondfoba", password: "p@ssword"),
            to: "/timelines/home?limit=2&minId=\(userStatuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
        #expect(statusesFromApi.data[0].note == "Min note 8", "First status is not visible.")
        #expect(statusesFromApi.data[1].note == "Min note 7", "Second status is not visible.")
    }
    
    @Test("Statuses should be returned with maxId")
    func statusesShouldBeReturnedWithMaxId() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "rickfoba")
        let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Max note", amount: 10)
        let userStatuses = try await application.createUserStatus(type: .owner, user: user, statuses: statuses)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try application.getResponse(
            as: .user(userName: "rickfoba", password: "p@ssword"),
            to: "/timelines/home?limit=2&maxId=\(userStatuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
        #expect(statusesFromApi.data[0].note == "Max note 5", "First status is not visible.")
        #expect(statusesFromApi.data[1].note == "Max note 4", "Second status is not visible.")
    }
    
    @Test("Statuses should be returned with sinceId")
    func statusesShouldBeReturnedWithSinceId() async throws {

        // Arrange.
        let user = try await application.createUser(userName: "benfoba")
        let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Since note", amount: 10)
        let userStatuses = try await application.createUserStatus(type: .owner, user: user, statuses: statuses)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try application.getResponse(
            as: .user(userName: "benfoba", password: "p@ssword"),
            to: "/timelines/home?limit=20&sinceId=\(userStatuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        #expect(statusesFromApi.data.count == 4, "Statuses list should be returned.")
        #expect(statusesFromApi.data[0].note == "Since note 10", "First status is not visible.")
        #expect(statusesFromApi.data[1].note == "Since note 9", "Second status is not visible.")
        #expect(statusesFromApi.data[2].note == "Since note 8", "Third status is not visible.")
        #expect(statusesFromApi.data[3].note == "Since note 7", "Fourth status is not visible.")
    }
}
