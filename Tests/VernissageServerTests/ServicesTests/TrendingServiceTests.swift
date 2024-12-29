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
    
    @Test("User should be calculated as trending user when he have liked statuses.")
    func userShouldBeCalculatedAsTrendingUserWhenHeHaveLikedStatuses() async throws {
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
        await application.services.trendingService.calculateTrendingUsers(on: queueContext)
        
        // Arrange.
        let trendingUsers = try await application.getAllTrendingUsers()
        #expect(trendingUsers.first(where: { $0.user.userName == "carinbopol"}) != nil, "User should be marked as trenidng user")
    }
    
    @Test("Status should be calculated as trending status when he was liked.")
    func statusShouldBeCalculatedAsTrendingUserWhenHeWasLiked() async throws {
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
        await application.services.trendingService.calculateTrendingStatuses(on: queueContext)
        
        // Arrange.
        let trendingStatuses = try await application.getAllTrendingStatuses()
        #expect(trendingStatuses.first(where: { $0.status.id == statuses.first?.id}) != nil, "Status should be marked as trenidng status.")
    }
    
    @Test("Hashtag should be calculated as trending hashtag when he have liked statuses.")
    func hashtagShouldBeCalculatedAsTrendingHashtagWhenHeHaveLikedStatuses() async throws {
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
        await application.services.trendingService.calculateTrendingHashtags(on: queueContext)
        
        // Arrange.
        let trendingHashtags = try await application.getAllTrendingHashtags()
        #expect(trendingHashtags.first(where: { $0.hashtag == "black"}) != nil, "Hashtag should be marked as trenidng status.")
    }
}
