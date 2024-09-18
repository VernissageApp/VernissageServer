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

@Suite("GET /hashtag/:hashtag", .serialized, .tags(.timelines))
struct TimelinesHashtagActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("Statuses should be returned for unauthorized without params when public access is enabled")
    func statusesShouldBeReturnedForUnauthorizedWithoutParamsWhenPublicAccessIsEnabled() async throws {

        // Arrange.
        try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(true))

        let user = try await application.createUser(userName: "timredix")
        let (_, attachments) = try await application.createStatuses(user: user, notePrefix: "Public note #black #white", amount: 4)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try application.getResponse(
            to: "/timelines/hashtag/black?limit=2",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
        #expect(statusesFromApi.data[0].note == "Public note #black #white 4", "First status is not visible.")
        #expect(statusesFromApi.data[1].note == "Public note #black #white 3", "Second status is not visible.")
    }
    
    @Test("Statuses should be returned for unauthorized with minId when public access is enabled")
    func statusesShouldBeReturnedForUnauthorizedWithMinIdWhenPublicAccessIsEnabled() async throws {

        // Arrange.
        try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(true))

        let user = try await application.createUser(userName: "tomredix")
        let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Min note #red #yellow", amount: 10)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try application.getResponse(
            to: "/timelines/hashtag/red?limit=2&minId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
        #expect(statusesFromApi.data[0].note == "Min note #red #yellow 8", "First status is not visible.")
        #expect(statusesFromApi.data[1].note == "Min note #red #yellow 7", "Second status is not visible.")
    }
    
    @Test("Statuses should be returned for unauthorized with maxId when public access is enabled")
    func statusesShouldBeReturnedForUnauthorizedWithMaxIdWhenPublicAccessIsEnabled() async throws {

        // Arrange.
        try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(true))

        let user = try await application.createUser(userName: "ronredix")
        let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Max note #pink #brown", amount: 10)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try application.getResponse(
            to: "/timelines/hashtag/pink?limit=2&maxId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
        #expect(statusesFromApi.data[0].note == "Max note #pink #brown 5", "First status is not visible.")
        #expect(statusesFromApi.data[1].note == "Max note #pink #brown 4", "Second status is not visible.")
    }
    
    @Test("Statuses should be returned for unauthorized with sinceId when public access is enabled")
    func statusesShouldBeReturnedForUnauthorizedWithSinceIdWhenPublicAccessIsEnabled() async throws {

        // Arrange.
        try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(true))

        let user = try await application.createUser(userName: "gregredix")
        let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Since note #gray #blue", amount: 10)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusesFromApi = try application.getResponse(
            to: "/timelines/hashtag/blue?limit=20&sinceId=\(statuses[5].id!)",
            method: .GET,
            decodeTo: LinkableResultDto<StatusDto>.self
        )
        
        // Assert.
        #expect(statusesFromApi.data.count == 4, "Statuses list should be returned.")
        #expect(statusesFromApi.data[0].note == "Since note #gray #blue 10", "First status is not visible.")
        #expect(statusesFromApi.data[1].note == "Since note #gray #blue 9", "Second status is not visible.")
        #expect(statusesFromApi.data[2].note == "Since note #gray #blue 8", "Third status is not visible.")
        #expect(statusesFromApi.data[3].note == "Since note #gray #blue 7", "Fourth status is not visible.")
    }
    
    @Test("Statuses should not be returned for unauthorized when public access is disabled")
    func statusesShouldNotBeReturnedForUnauthorizedWhenPublicAccessIsDisabled() async throws {
        // Arrange.
        try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(false))
        
        // Act.
        let response = try application.sendRequest(
            to: "/timelines/hashtag/blue",
            method: .GET
        )

        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
