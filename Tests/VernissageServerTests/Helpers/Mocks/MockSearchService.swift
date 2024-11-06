//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Queues

final class MockSearchService: SearchServiceType {
    func search(query: String, searchType: VernissageServer.SearchTypeDto, on context: ExecutionContext) async throws -> VernissageServer.SearchResultDto {
        let searchService = SearchService()
        return try await searchService.search(query: query, searchType: searchType, on: context)
    }
    
    func downloadRemoteUser(activityPubProfile: String, on context: ExecutionContext) async throws -> VernissageServer.User? {
        let searchService = SearchService()
        return try await searchService.downloadRemoteUser(activityPubProfile: activityPubProfile, on: context)
    }
    
    func getRemoteActivityPubProfile(userName: String, on context: ExecutionContext) async -> String? {
        let name = userName.split(separator: "@").first
        let domain = userName.split(separator: "@").last
        
        return "https://\(domain ?? "example.com")/users/\(name ?? "user")}"
    }
}

