//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Queues

final class MockSearchService: SearchServiceType {
    func search(query: String, searchType: VernissageServer.SearchTypeDto, request: Vapor.Request) async throws -> VernissageServer.SearchResultDto {
        let searchService = SearchService()
        return try await searchService.search(query: query, searchType: searchType, request: request)
    }
    
    func downloadRemoteUser(activityPubProfile: String, on request: Vapor.Request) async -> VernissageServer.SearchResultDto {
        let searchService = SearchService()
        return await searchService.downloadRemoteUser(activityPubProfile: activityPubProfile, on: request)
    }
    
    func downloadRemoteUser(activityPubProfile: String, on context: Queues.QueueContext) async throws -> VernissageServer.User? {
        let searchService = SearchService()
        return try await searchService.downloadRemoteUser(activityPubProfile: activityPubProfile, on: context)
    }
    
    func getRemoteActivityPubProfile(userName: String, on request: Vapor.Request) async -> String? {
        let name = userName.split(separator: "@").first
        let domain = userName.split(separator: "@").last
        
        return "https://\(domain ?? "example.com")/users/\(name ?? "user")}"
    }
}

