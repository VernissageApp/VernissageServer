//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing
import Queues

@Suite("TrendingService")
struct TrendingServiceTests {
    
    var application: Application!
    
    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }
    
    @Test
    func `User should be calculated as trending user when he have liked statuses.`() async throws {
        // Arrange.
        let user1 = try await application.createUser(userName: "carinbopol")
        let user2 = try await application.createUser(userName: "adambopol")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unfavorited #black #white", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        try await application.favouriteStatus(user: user2, status: statuses.first!)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "TrendingJob"))
        await application.services.trendingService.calculateTrendingUsers(period: .daily, on: queueContext)
        
        // Arrange.
        let trendingUsers = try await application.getAllTrendingUsers()
        #expect(trendingUsers.first(where: { $0.user.userName == "carinbopol"}) != nil, "User should be marked as trenidng user")
    }
    
    @Test
    func `Status should be calculated as trending status when he was liked.`() async throws {
        // Arrange.
        let user1 = try await application.createUser(userName: "mariabopol")
        let user2 = try await application.createUser(userName: "victorbopol")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unfavorited #black #white", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        try await application.favouriteStatus(user: user2, status: statuses.first!)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "TrendingJob"))
        await application.services.trendingService.calculateTrendingStatuses(period: .daily, on: queueContext)
        
        // Arrange.
        let trendingStatuses = try await application.getAllTrendingStatuses()
        #expect(trendingStatuses.first(where: { $0.status.id == statuses.first?.id}) != nil, "Status should be marked as trenidng status.")
    }

    @Test
    func `More liked status should be returned first in trending statuses.`() async throws {
        // Arrange.
        let author = try await application.createUser(userName: "trendingstatusauthor")
        let user1 = try await application.createUser(userName: "trendingstatusliker1")
        let user2 = try await application.createUser(userName: "trendingstatusliker2")
        let user3 = try await application.createUser(userName: "trendingstatusliker3")
        let (statuses, attachments) = try await application.createStatuses(user: author, notePrefix: "Ordered trending status", amount: 2)
        defer {
            application.clearFiles(attachments: attachments)
        }

        let lessLikedStatus = try #require(statuses.first)
        let moreLikedStatus = try #require(statuses.dropFirst().first)
        try await application.favouriteStatus(user: user1, status: lessLikedStatus)
        try await application.favouriteStatus(user: user2, status: moreLikedStatus)
        try await application.favouriteStatus(user: user3, status: moreLikedStatus)

        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "TrendingJob"))
        await application.services.trendingService.calculateTrendingStatuses(period: .daily, on: queueContext)

        // Assert.
        let trendingStatuses = try await application.services.trendingService.statuses(
            linkableParams: LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 2),
            period: .daily,
            on: ExecutionContext(context: queueContext)
        )

        #expect(trendingStatuses.data.first?.id == moreLikedStatus.id, "Status liked twice should be first on trending statuses list.")
    }
    
    @Test
    func `Hashtag should be calculated as trending hashtag when he have liked statuses.`() async throws {
        // Arrange.
        let user1 = try await application.createUser(userName: "trondbopol")
        let user2 = try await application.createUser(userName: "trachetbopol")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unfavorited #black #white", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        try await application.favouriteStatus(user: user2, status: statuses.first!)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "TrendingJob"))
        await application.services.trendingService.calculateTrendingHashtags(period: .daily, on: queueContext)
        
        // Arrange.
        let trendingHashtags = try await application.getAllTrendingHashtags()
        #expect(trendingHashtags.first(where: { $0.hashtag == "black"}) != nil, "Hashtag should be marked as trenidng status.")
    }
    
    @Test
    func `Hashtag should prefer readable mixed case representation when available.`() async throws {
        // Arrange.
        let user1 = try await application.createUser(userName: "hashtagcaseauthor")
        let user2 = try await application.createUser(userName: "hashtagcaseliker")
        
        let (lowercaseStatuses, lowercaseAttachments) = try await application.createStatuses(
            user: user1,
            notePrefix: "Lowercase hashtag #streetphoto",
            amount: 3
        )
        
        let (mixedCaseStatuses, mixedCaseAttachments) = try await application.createStatuses(
            user: user1,
            notePrefix: "Mixed case hashtag #StreetPhoto",
            amount: 1
        )
        
        defer {
            application.clearFiles(attachments: lowercaseAttachments + mixedCaseAttachments)
        }
        
        for status in lowercaseStatuses + mixedCaseStatuses {
            try await application.favouriteStatus(user: user2, status: status)
        }
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "TrendingJob"))
        await application.services.trendingService.calculateTrendingHashtags(period: .daily, on: queueContext)
        
        // Assert.
        let trendingHashtags = try await application.getAllTrendingHashtags()
        let streetPhotoTrending = trendingHashtags.first(where: {
            $0.trendingPeriod == .daily && $0.hashtagNormalized == "STREETPHOTO"
        })
        
        #expect(streetPhotoTrending != nil, "StreetPhoto hashtag should be calculated as trending.")
        #expect(streetPhotoTrending?.hashtag == "StreetPhoto", "Trending hashtag should prefer mixed case representation.")
        #expect(streetPhotoTrending?.amount == 4, "Trending hashtag amount should count all case variants.")
    }
}
