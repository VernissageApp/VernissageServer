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

@Suite("GET /public", .serialized, .tags(.timelines))
struct TimelinesPublicActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Statuses should be returned for unauthorized without params when public access is enabled")
    func statusesShouldBeReturnedForUnauthorizedWithoutParamsWhenPublicAccessIsEnabled() async throws {

        // Arrange.
        try await application.updateSetting(key: .showLocalTimelineForAnonymous, value: .boolean(true))

        let user = try await application.createUser(userName: "timpinq")
        let (_, attachments) = try await application.createStatuses(user: user, notePrefix: "Public note", amount: 4)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try application.getResponse(
            to: "/timelines/public?limit=2",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
        #expect(statusesFromApi.data[0].note == "Public note 4", "First status is not visible.")
        #expect(statusesFromApi.data[1].note == "Public note 3", "Second status is not visible.")
    }
    
    @Test("Statuses should be returned for unauthorized with minId when public access is enabled")
    func statusesShouldBeReturnedForUnauthorizedWithMinIdWhenPublicAccessIsEnabled() async throws {

        // Arrange.
        try await application.updateSetting(key: .showLocalTimelineForAnonymous, value: .boolean(true))

        let user = try await application.createUser(userName: "tompinq")
        let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Min note", amount: 10)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try application.getResponse(
            to: "/timelines/public?limit=2&minId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
        #expect(statusesFromApi.data[0].note == "Min note 8", "First status is not visible.")
        #expect(statusesFromApi.data[1].note == "Min note 7", "Second status is not visible.")
    }
    
    @Test("Statuses should be returned for unauthorized with maxId when public access is enabled")
    func statusesShouldBeReturnedForUnauthorizedWithMaxIdWhenPublicAccessIsEnabled() async throws {

        // Arrange.
        try await application.updateSetting(key: .showLocalTimelineForAnonymous, value: .boolean(true))

        let user = try await application.createUser(userName: "ronpinq")
        let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Max note", amount: 10)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try application.getResponse(
            to: "/timelines/public?limit=2&maxId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
        #expect(statusesFromApi.data[0].note == "Max note 5", "First status is not visible.")
        #expect(statusesFromApi.data[1].note == "Max note 4", "Second status is not visible.")
    }
    
    @Test("Statuses should be returned for unauthorized with sinceId when public access is enabled")
    func statusesShouldBeReturnedForUnauthorizedWithSinceIdWhenPublicAccessIsEnabled() async throws {

        // Arrange.
        try await application.updateSetting(key: .showLocalTimelineForAnonymous, value: .boolean(true))

        let user = try await application.createUser(userName: "gregpinq")
        let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Since note", amount: 10)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try application.getResponse(
            to: "/timelines/public?limit=20&sinceId=\(statuses[5].id!)",
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
    
    @Test("Statuses should not be returned when public access is disabled")
    func statusesShouldNotBeReturnedWhenPublicAccessIsDisabled() async throws {
        // Arrange.
        try await application.updateSetting(key: .showLocalTimelineForAnonymous, value: .boolean(false))
        
        // Act.
        let response = try application.sendRequest(
            to: "/timelines/public?limit=2",
            method: .GET
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
