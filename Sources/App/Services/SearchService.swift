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
        if self.isLocalSearch(query: query, on: request) {
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
        let flexiFieldService = request.application.services.flexiFieldService
        
        // In case of error we have to return empty list.
        guard let users = try? await usersService.search(query: query, on: request, page: 1, size: 20) else {
            request.logger.warning("Error during filtering local users.")
            return SearchResultDto(users: [])
        }
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request)
        
        // Map databse user into DTO objects.
        let userDtos = await users.items.parallelMap { user in
            let flexiFields = try? await flexiFieldService.getFlexiFields(on: request, for: user.requireID())
            return UserDto(from: user, flexiFields: flexiFields ?? [], baseStoragePath: baseStoragePath)
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
        let profileFileName = await self.downloadProfileImage(personProfile: personProfile, on: request)
        
        // Update profile in internal database and return it.
        return await self.update(personProfile: personProfile, profileFileName: profileFileName, on: request)
    }
    
    private func downloadProfileImage(personProfile: PersonDto, on request: Request) async -> String? {
        if personProfile.icon.url.isEmpty == false {
            let storageService = request.application.services.storageService
            let fileName = try? await storageService.dowload(url: personProfile.icon.url, on: request)
            request.logger.info("Profile icon has been downloaded and saved: '\(fileName ?? "<unknown>")'.")
            
            return fileName
        }
        
        return nil
    }
    
    private func update(personProfile: PersonDto, profileFileName: String?, on request: Request) async -> SearchResultDto {
        do {
            let usersService = request.application.services.usersService
            let flexiFieldService = request.application.services.flexiFieldService
            
            let userFromDb = try await usersService.get(on: request, activityPubProfile: personProfile.id)
            let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request)
            
            // If user not exist we have to create his account in internal database and return it.
            if userFromDb == nil {
                let newUser = try await usersService.create(on: request, basedOn: personProfile, withAvatarFileName: profileFileName)
                let userDto = UserDto(from: newUser, flexiFields: [], baseStoragePath: baseStoragePath)

                return SearchResultDto(users: [userDto])
            } else {
                // If user exist then we have to update uhis account in internal database and return it.
                let updatedUser = try await usersService.update(user: userFromDb!, on: request, basedOn: personProfile, withAvatarFileName: profileFileName)
                let flexiFields = try await flexiFieldService.getFlexiFields(on: request, for: userFromDb!.requireID())

                let userDto = UserDto(from: updatedUser, flexiFields: flexiFields, baseStoragePath: baseStoragePath)

                return SearchResultDto(users: [userDto])
            }
        } catch {
            request.logger.warning("Error during updating remote user in local database: '\(error.localizedDescription)'.")
            return SearchResultDto(users: [])
        }
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
    
    private func isLocalSearch(query: String, on request: Request) -> Bool {
        let queryParts = query.split(separator: "@")
        if queryParts.count == 1 {
            return true
        }
        
        let applicationSettings = request.application.settings.cached!
        if queryParts[1].uppercased() == applicationSettings.domain.uppercased() {
            return true
        }
        
        return false
    }
}


import Foundation

// https://gist.github.com/DougGregor/92a2e4f6e11f6d733fb5065e9d1c880f
extension Collection {
    func parallelMap<T>(
        parallelism requestedParallelism: Int? = nil,
        _ transform: @escaping (Element) async throws -> T
    ) async rethrows -> [T] {
        let defaultParallelism = 2
        let parallelism = requestedParallelism ?? defaultParallelism

        let n = count
        if n == 0 {
            return []
        }
        return try await withThrowingTaskGroup(of: (Int, T).self, returning: [T].self) { group in
            var result = [T?](repeatElement(nil, count: n))

            var i = self.startIndex
            var submitted = 0

            func submitNext() async throws {
                if i == self.endIndex { return }

                group.addTask { [submitted, i] in
                    let value = try await transform(self[i])
                    return (submitted, value)
                }
                submitted += 1
                formIndex(after: &i)
            }

            // submit first initial tasks
            for _ in 0 ..< parallelism {
                try await submitNext()
            }

            // as each task completes, submit a new task until we run out of work
            while let (index, taskResult) = try await group.next() {
                result[index] = taskResult

                try Task.checkCancellation()
                try await submitNext()
            }

            assert(result.count == n)
            return Array(result.compactMap { $0 })
        }
    }

    func parallelEach(
        parallelism requestedParallelism: Int? = nil,
        _ work: @escaping (Element) async throws -> Void
    ) async rethrows {
        _ = try await parallelMap {
            try await work($0)
        }
    }
}
