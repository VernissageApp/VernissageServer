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

extension TrendingControllerTests {
    
    @Suite("GET /statuses", .serialized, .tags(.trending))
    struct TrendingStatusesActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Trending statuses should be returned for unauthorized user when public access is enabled")
        func trendingStatusesShouldBeReturnedForUnauthorizedUserWhenPublicAccessIsEnabled() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showTrendingForAnonymous, value: .boolean(true))
            
            let user = try await application.createUser(userName: "greggobels")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Public note", amount: 4)
            _ = try await application.createUserStatus(type: .owner, user: user, statuses: statuses)
            defer {
                application.clearFiles(attachments: attachments)
            }
            try await application.createTrendingStatus(trendingPeriod: .daily, statusId: statuses[0].id!)
            try await application.createTrendingStatus(trendingPeriod: .daily, statusId: statuses[1].id!)
            try await application.createTrendingStatus(trendingPeriod: .daily, statusId: statuses[2].id!)
            try await application.createTrendingStatus(trendingPeriod: .monthly, statusId: statuses[3].id!)
            
            // Act.
            let statusesFromApi = try application.getResponse(
                to: "/trending/statuses?limit=2&period=daily",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Public note 3", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Public note 2", "Second status is not visible.")
        }
        
        @Test("Trending statuses should not be returned for unauthorized user when public access is disabled")
        func testTrendingStatusesShouldNotBeReturnedForUnauthorizedUserWhenPublicAccessIsDisabled() async throws {
            // Arrange.
            try await application.updateSetting(key: .showTrendingForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try application.sendRequest(
                to: "/trending/statuses?limit=2&period=daily",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
