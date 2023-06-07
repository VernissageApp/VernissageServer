//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

extension Application.Services {
    struct SearchServiceKey: StorageKey {
        typealias Value = SearchServiceType
    }

    var searchService: SearchServiceType {
        get {
            self.application.storage[SearchServiceKey.self] ?? SearchService()
        }
        nonmutating set {
            self.application.storage[SearchServiceKey.self] = newValue
        }
    }
}

protocol SearchServiceType {
    func search(query: String, searchType: SearchTypetDto, request: Request) async throws -> SearchResultDto
}

final class SearchService: SearchServiceType {
    func search(query: String, searchType: SearchTypetDto, request: Request) async throws -> SearchResultDto {
        switch searchType {
        case .users:
            return await self.searchByUsers(query: query, on: request)
        case .statuses:
            return self.searchByStatuses(query: query, on: request)
        case .hashtags:
            return self.searchByHashtags(query: query, on: request)
        }
    }
    
    private func searchByUsers(query: String, on request: Request) async -> SearchResultDto {
        if self.isLocalSearch(query: query) {
            return await self.searchByLocalUsers(query: query, on: request)
        } else {
            return await self.searchByRemoteUsers(query: query, on: request)
        }
    }
    
    private func searchByStatuses(query: String, on request: Request) -> SearchResultDto {
        return SearchResultDto(statuses: [])
    }

    private func searchByHashtags(query: String, on request: Request) -> SearchResultDto {
        return SearchResultDto(hashtags: [])
    }
    
    private func searchByLocalUsers(query: String, on request: Request) async -> SearchResultDto {
        let usersService = request.application.services.usersService
        
        // In case of error we have to return empty list.
        guard let users = try? await usersService.search(query: query, on: request, page: 1, size: 20) else {
            request.logger.warning("Error during filtering local users.")
            return SearchResultDto(users: [])
        }
        
        // Map databse user into DTO objects.
        let userDtos = users.items.map { user in
            UserDto(from: user)
        }
        
        return SearchResultDto(users: userDtos)
    }
    
    private func searchByRemoteUsers(query: String, on request: Request) async -> SearchResultDto {
        // Get hostname from user query.
        guard let baseUrl = self.getBaseUrl(from: query) else {
            request.logger.warning("Base url cannot be parsed from user query: '\(query)'.")
            return SearchResultDto(users: [])
        }
        
        // Url cannot be mentioned in instance blocked domains.
        let isBlockedDomain = await self.existsInInstanceBlockedList(url: baseUrl, on: request)
        guard isBlockedDomain == false else {
            request.logger.warning("Base URL is listed in blocked instance domains: '\(query)'.")
            return SearchResultDto(users: [])
        }
        
        // Search user profile by remote webfinger.
        guard let activityPubProfile = await self.getActivityPubProfile(query: query, baseUrl: baseUrl) else {
            request.logger.warning("ActivityPub profile URL cannot be downloaded: '\(baseUrl)'.")
            return SearchResultDto(users: [])
        }
        
        // Download user profile from remote server.
        let activityPubClient = ActivityPubClient()
        guard let personProfile = try? await activityPubClient.person(id: activityPubProfile) else {
            request.logger.warning("ActivityPub profile cannot be downloaded: '\(activityPubProfile)'.")
            return SearchResultDto(users: [])
        }
        
        // Download resources (like user profile image) from remote server.
        await self.downloadRemoteResources(personProfile: personProfile)
        
        // Update profile in internal database and return it.
        return await self.update(personProfile: personProfile, on: request)
    }
    
    private func update(personProfile: PersonDto, on request: Request) async -> SearchResultDto {
        do {
            let usersService = request.application.services.usersService
            let userFromDb = try await usersService.get(on: request, activityPubProfile: personProfile.id)
            
            // If user not exist we have to create his account in internal database and return it.
            if userFromDb == nil {
                let newUser = try await usersService.create(on: request, basedOn: personProfile)
                let userDto = UserDto(from: newUser)

                return SearchResultDto(users: [userDto])
            } else {
                // If user exist then we have to update uhis account in internal database and return it.
                let updatedUser = try await usersService.update(user: userFromDb!, on: request, basedOn: personProfile)
                let userDto = UserDto(from: updatedUser)

                return SearchResultDto(users: [userDto])
            }
        } catch {
            request.logger.warning("Error during updating remote user in local database: '\(error.localizedDescription)'.")
            return SearchResultDto(users: [])
        }
    }
    
    private func downloadRemoteResources(personProfile: PersonDto) async {
        // TODO: Download remote resources from remote server (like user profile).
    }
    
    private func getActivityPubProfile(query: String, baseUrl: URL) async -> String? {
        let activityPubClient = ActivityPubClient(baseURL: baseUrl)
        guard let webfingerResult = try? await activityPubClient.webfinger(resource: query) else {
            return nil
        }
                
        guard let activityPubProfile = webfingerResult.links.first(where: { $0.rel == "self" })?.href else {
            return nil
        }
        
        return activityPubProfile
    }
    
    private func existsInInstanceBlockedList(url: URL, on request: Request) async -> Bool {
        let instanceBlockedDomainsService = request.application.services.instanceBlockedDomainsService
        let exists = try? await instanceBlockedDomainsService.exists(url: url, on: request)
        
        return exists ?? false
    }
    
    private func getBaseUrl(from query: String) -> URL? {
        let domainFromQuery = query.split(separator: "@").last ?? ""
        return URL(string: "https://\(domainFromQuery)")
    }
    
    private func isLocalSearch(query: String) -> Bool {
        query.contains("@") == false
    }
}
