//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit
import Queues

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
    func downloadRemoteUser(profileUrl: String, on request: Request) async -> SearchResultDto
    func downloadRemoteUser(profileUrl: String, on context: QueueContext) async throws -> User?
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
    
    func downloadRemoteUser(profileUrl: String, on request: Request) async -> SearchResultDto {
        guard let personProfile = await self.downloadProfile(profileUrl: profileUrl, application: request.application) else {
            request.logger.warning("ActivityPub profile cannot be downloaded: '\(profileUrl)'.")
            return SearchResultDto(users: [])
        }
        
        // Download profile icon from remote server.
        let profileIconFileName = await self.downloadProfileImage(personProfile: personProfile, on: request)

        // Download profile header from remote server.
        let profileImageFileName = await self.downloadHeaderImage(personProfile: personProfile, on: request)
        
        // Update profile in internal database and return it.
        guard let user = await self.update(personProfile: personProfile,
                                           profileIconFileName: profileIconFileName,
                                           profileImageFileName: profileImageFileName,
                                           on: request.application) else {
            return SearchResultDto(users: [])
        }
        
        let flexiFieldService = request.application.services.flexiFieldService
        let storageService = request.application.services.storageService
        
        let baseStoragePath = storageService.getBaseStoragePath(on: request.application)
        let flexiFields = try? await flexiFieldService.getFlexiFields(on: request.db, for: user.requireID())
        let userDto = UserDto(from: user, flexiFields: flexiFields ?? [], baseStoragePath: baseStoragePath)

        return SearchResultDto(users: [userDto])
    }

    func downloadRemoteUser(profileUrl: String, on context: QueueContext) async throws -> User? {
        let usersService = context.application.services.usersService
        
        if let userFromDatabase = try await usersService.get(on: context.application.db, activityPubProfile: profileUrl),
            max((userFromDatabase.updatedAt ?? Date.distantPast), (userFromDatabase.createdAt ?? Date.distantPast)) > Date.yesterday
        {
            return userFromDatabase
        }
        
        guard let personProfile = await self.downloadProfile(profileUrl: profileUrl, application: context.application) else {
            context.logger.warning("ActivityPub profile cannot be downloaded: '\(profileUrl)'.")
            return nil
        }
        
        // Download profile icon from remote server.
        let profileIconFileName = await self.downloadProfileImage(personProfile: personProfile, on: context)

        // Download profile header from remote server.
        let profileImageFileName = await self.downloadHeaderImage(personProfile: personProfile, on: context)
        
        // Update profile in internal database and return it.
        return await self.update(personProfile: personProfile,
                                 profileIconFileName: profileIconFileName,
                                 profileImageFileName: profileImageFileName,
                                 on: context.application)
    }
    
    private func downloadProfile(profileUrl: String, application: Application) async -> PersonDto? {
        do {
            let activityPubClient = ActivityPubClient()
            return try await activityPubClient.person(id: profileUrl)
        } catch {
            application.logger.error("Error during download profile: '\(profileUrl)'. Error: \(error).")
        }
            
        return nil
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
        
        // In case of error we have to return empty list.
        guard let users = try? await usersService.search(query: query, on: request, page: 1, size: 20) else {
            request.logger.warning("Error during filtering local users.")
            return SearchResultDto(users: [])
        }
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        
        // Map databse user into DTO objects.
        let userDtos = await users.items.parallelMap { user in
            let flexiFields = try? await user.$flexiFields.get(on: request.db)
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
        return await self.downloadRemoteUser(profileUrl: activityPubProfile, on: request)
    }
    
    private func downloadProfileImage(personProfile: PersonDto, on request: Request) async -> String? {
        guard let icon = personProfile.icon else {
            return nil
        }
        
        if icon.url.isEmpty == false {
            let storageService = request.application.services.storageService
            let fileName = try? await storageService.dowload(url: icon.url, on: request)
            request.logger.info("Profile icon has been downloaded and saved: '\(fileName ?? "<unknown>")'.")
            
            return fileName
        }
        
        return nil
    }
    
    private func downloadProfileImage(personProfile: PersonDto, on context: QueueContext) async -> String? {
        guard let icon = personProfile.icon else {
            return nil
        }
        
        if icon.url.isEmpty == false {
            let storageService = context.application.services.storageService
            let fileName = try? await storageService.dowload(url: icon.url, on: context)
            context.logger.info("Profile icon has been downloaded and saved: '\(fileName ?? "<unknown>")'.")
            
            return fileName
        }
        
        return nil
    }
    
    private func downloadHeaderImage(personProfile: PersonDto, on request: Request) async -> String? {
        guard let image = personProfile.image else {
            return nil
        }
        
        if image.url.isEmpty == false {
            let storageService = request.application.services.storageService
            let fileName = try? await storageService.dowload(url: image.url, on: request)
            request.logger.info("Header image has been downloaded and saved: '\(fileName ?? "<unknown>")'.")
            
            return fileName
        }
        
        return nil
    }
    
    private func downloadHeaderImage(personProfile: PersonDto, on context: QueueContext) async -> String? {
        guard let image = personProfile.image else {
            return nil
        }
        
        if image.url.isEmpty == false {
            let storageService = context.application.services.storageService
            let fileName = try? await storageService.dowload(url: image.url, on: context)
            context.logger.info("Header image has been downloaded and saved: '\(fileName ?? "<unknown>")'.")
            
            return fileName
        }
        
        return nil
    }
    
    private func update(personProfile: PersonDto, profileIconFileName: String?, profileImageFileName: String?, on application: Application) async -> User? {
        do {
            let usersService = application.services.usersService
            let userFromDb = try await usersService.get(on: application.db, activityPubProfile: personProfile.id)
            
            // If user not exist we have to create his account in internal database and return it.
            if userFromDb == nil {
                let newUser = try await usersService.create(on: application.db,
                                                            basedOn: personProfile,
                                                            withAvatarFileName: profileIconFileName,
                                                            withHeaderFileName: profileImageFileName)

                return newUser
            } else {
                // If user exist then we have to update uhis account in internal database and return it.
                let updatedUser = try await usersService.update(user: userFromDb!,
                                                                on: application.db,
                                                                basedOn: personProfile,
                                                                withAvatarFileName: profileIconFileName,
                                                                withHeaderFileName: profileImageFileName)

                return updatedUser
            }
        } catch {
            application.logger.warning("Error during creating/updating remote user: '\(personProfile.id)' in local database: '\(error.localizedDescription)'.")
            return nil
        }
    }
    
    private func getActivityPubProfile(query: String, baseUrl: URL) async -> String? {
        let activityPubClient = ActivityPubClient()
        guard let webfingerResult = try? await activityPubClient.webfinger(baseUrl: baseUrl, resource: query) else {
            return nil
        }
                
        guard let activityPubProfile = webfingerResult.links.first(where: { $0.rel == "self" })?.href else {
            return nil
        }
        
        return activityPubProfile
    }
    
    private func existsInInstanceBlockedList(url: URL, on request: Request) async -> Bool {
        let instanceBlockedDomainsService = request.application.services.instanceBlockedDomainsService
        let exists = try? await instanceBlockedDomainsService.exists(on: request.db, url: url)
        
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
