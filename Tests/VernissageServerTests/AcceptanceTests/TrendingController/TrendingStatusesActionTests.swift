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

extension ControllersTests {
    
    @Suite("Trending (GET /trending/statuses)", .serialized, .tags(.trending))
    struct TrendingStatusesActionTests {
        enum HiddenRelationship: String, CaseIterable {
            case muted
            case blocked
        }

        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Trending statuses should be returned for unauthorized user when public access is enabled`() async throws {
            
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
            let statusesFromApi = try await application.getResponse(
                to: "/trending/statuses?limit=2&period=daily",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Public note 3", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Public note 2", "Second status is not visible.")
        }
        
        @Test
        func `Trending statuses should not be returned when status author is deleted`() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showTrendingForAnonymous, value: .boolean(true))
            
            let user = try await application.createUser(userName: "deletedtrendingstatus")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Deleted trending status", amount: 1)
            _ = try await application.createUserStatus(type: .owner, user: user, statuses: statuses)
            try await application.createTrendingStatus(trendingPeriod: .daily, statusId: try #require(statuses.first?.id))
            try await user.delete(on: application.db)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try await application.getResponse(
                to: "/trending/statuses?limit=2&period=daily",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            let deletedStatus = try #require(statuses.first)
            #expect(statusesFromApi.data.contains(where: { $0.id == deletedStatus.stringId() }) == false, "Statuses created by deleted users should not be returned.")
        }

        @Test(arguments: HiddenRelationship.allCases)
        func `Trending statuses from hidden accounts should not be returned for authorized user`(
            relationship: HiddenRelationship
        ) async throws {
            // Arrange.
            let suffix = relationship.rawValue
            let viewer = try await application.createUser(userName: "trendingstatusviewer\(suffix)")
            let visibleAuthor = try await application.createUser(userName: "trendingstatusvisible\(suffix)")
            let hiddenAuthor = try await application.createUser(userName: "trendingstatushidden\(suffix)")

            let (visibleStatuses, visibleAttachments) = try await application.createStatuses(
                user: visibleAuthor,
                notePrefix: "Visible trending status \(suffix)",
                amount: 1
            )
            let (hiddenStatuses, hiddenAttachments) = try await application.createStatuses(
                user: hiddenAuthor,
                notePrefix: "Hidden trending status \(suffix)",
                amount: 1
            )
            defer {
                application.clearFiles(attachments: visibleAttachments + hiddenAttachments)
            }

            let visibleStatus = try #require(visibleStatuses.first)
            let hiddenStatus = try #require(hiddenStatuses.first)
            try await application.createTrendingStatus(trendingPeriod: .daily, statusId: try visibleStatus.requireID())
            try await application.createTrendingStatus(trendingPeriod: .daily, statusId: try hiddenStatus.requireID())

            switch relationship {
            case .muted:
                _ = try await application.createUserMute(
                    userId: try viewer.requireID(),
                    mutedUserId: try hiddenAuthor.requireID(),
                    muteStatuses: true,
                    muteReblogs: false,
                    muteNotifications: false
                )
            case .blocked:
                _ = try await application.createUserBlockedUser(
                    userId: try viewer.requireID(),
                    blockedUserId: try hiddenAuthor.requireID(),
                    reason: ""
                )
            }

            // Act.
            let statusesFromApi = try await application.getResponse(
                as: .user(userName: viewer.userName, password: "p@ssword"),
                to: "/trending/statuses?limit=1&period=daily",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )

            // Assert.
            #expect(statusesFromApi.data.count == 1, "Filtering should happen before applying the page limit.")
            #expect(statusesFromApi.data.first?.id == visibleStatus.stringId(), "Only statuses from visible accounts should be returned.")
            #expect(statusesFromApi.data.contains(where: { $0.id == hiddenStatus.stringId() }) == false, "Statuses from hidden accounts should not be returned.")
        }
        
        @Test
        func `Trending statuses should not be returned for unauthorized user when public access is disabled`() async throws {
            // Arrange.
            try await application.updateSetting(key: .showTrendingForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try await application.sendRequest(
                to: "/trending/statuses?limit=2&period=daily",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
