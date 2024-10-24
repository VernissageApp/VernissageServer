//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit
import Queues
import RegexBuilder
import SwiftSoup

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

@_documentation(visibility: private)
protocol SearchServiceType: Sendable {
    func search(query: String, searchType: SearchTypeDto, request: Request) async throws -> SearchResultDto
    func downloadRemoteUser(activityPubProfile: String, on request: Request) async -> SearchResultDto
    func downloadRemoteUser(activityPubProfile: String, on context: QueueContext) async throws -> User?
    func getRemoteActivityPubProfile(userName: String, on request: Request) async -> String?
}

/// A service for searching in the local and remote system.
final class SearchService: SearchServiceType {
    func search(query: String, searchType: SearchTypeDto, request: Request) async throws -> SearchResultDto {
        let queryWithoutPrefix = String(query.trimmingPrefix("@"))
        
        switch searchType {
        case .users:
            return await self.searchByUsers(query: queryWithoutPrefix, on: request)
        case .statuses:
            return await self.searchByStatuses(query: queryWithoutPrefix, on: request)
        case .hashtags:
            return await self.searchByHashtags(query: queryWithoutPrefix, on: request)
        }
    }
    
    func downloadRemoteUser(activityPubProfile: String, on request: Request) async -> SearchResultDto {
        guard let personProfile = await self.downloadProfile(activityPubProfile: activityPubProfile, application: request.application) else {
            request.logger.warning("ActivityPub profile cannot be downloaded: '\(activityPubProfile)'.")
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
        let usersService = request.application.services.usersService
        
        let flexiFields = try? await flexiFieldService.getFlexiFields(on: request.db, for: user.requireID())
        let userDto = await usersService.convertToDto(on: request, user: user, flexiFields: flexiFields, roles: nil, attachSensitive: false)
        
        // Enqueue job for flexi field URL validator.
        if let flexiFields {
            try? await flexiFieldService.dispatchUrlValidator(on: request, flexiFields: flexiFields)
        }
        
        return SearchResultDto(users: [userDto])
    }
    
    func downloadRemoteUser(activityPubProfile: String, on context: QueueContext) async throws -> User? {
        let usersService = context.application.services.usersService
        
        let userFromDatabase = try await usersService.get(on: context.application.db, activityPubProfile: activityPubProfile)
        if let userFromDatabase, max((userFromDatabase.updatedAt ?? Date.distantPast), (userFromDatabase.createdAt ?? Date.distantPast)) > Date.yesterday {
            return userFromDatabase
        }
        
        guard let personProfile = await self.downloadProfile(activityPubProfile: activityPubProfile, application: context.application) else {
            context.logger.warning("ActivityPub profile cannot be downloaded: '\(activityPubProfile)'.")
            return userFromDatabase
        }
        
        // Download profile icon from remote server.
        let profileIconFileName = await self.downloadProfileImage(personProfile: personProfile, on: context)
        
        // Download profile header from remote server.
        let profileImageFileName = await self.downloadHeaderImage(personProfile: personProfile, on: context)
        
        // Update profile in internal database and return it.
        let user = await self.update(personProfile: personProfile,
                                     profileIconFileName: profileIconFileName,
                                     profileImageFileName: profileImageFileName,
                                     on: context.application)
        
        if let user {
            // Downlaod updated flexi fields.
            let flexiFieldService = context.application.services.flexiFieldService
            let flexiFields = try? await flexiFieldService.getFlexiFields(on: context.application.db, for: user.requireID())
            
            // Enqueue job for flexi field URL validator.
            if let flexiFields {
                try? await flexiFieldService.dispatchUrlValidator(on: context, flexiFields: flexiFields)
            }
        }
        
        return user
    }
    
    func getRemoteActivityPubProfile(userName: String, on request: Request) async -> String? {
        // Get hostname from user query.
        guard let baseUrl = self.getBaseUrl(from: userName) else {
            request.logger.notice("Base url cannot be parsed from user name: '\(userName)'.")
            return nil
        }
        
        // Url cannot be mentioned in instance blocked domains.
        let isBlockedDomain = await self.existsInInstanceBlockedList(url: baseUrl, on: request)
        guard isBlockedDomain == false else {
            request.logger.notice("Base URL is listed in blocked instance domains: '\(userName)'.")
            return nil
        }
        
        // Search user profile by remote webfinger.
        guard let activityPubProfile = await self.getActivityPubProfile(query: userName, baseUrl: baseUrl, on: request.application) else {
            request.logger.warning("ActivityPub profile '\(userName)' cannot be downloaded from: '\(baseUrl)'.")
            return nil
        }
        
        return activityPubProfile
    }
    
    private func downloadProfile(activityPubProfile: String, application: Application) async -> PersonDto? {
        do {
            let usersService = application.services.usersService
            guard let defaultSystemUser = try await usersService.getDefaultSystemUser(on: application.db) else {
                throw ActivityPubError.missingInstanceAdminAccount
            }
            
            guard let privateKey = defaultSystemUser.privateKey else {
                throw ActivityPubError.missingInstanceAdminPrivateKey
            }
            
            guard let activityPubProfileUrl = URL(string: activityPubProfile) else {
                throw ActivityPubError.unrecognizedActivityPubProfileUrl
            }
            
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: activityPubProfileUrl.host)
            let userProfile = try await activityPubClient.person(id: activityPubProfile, activityPubProfile: defaultSystemUser.activityPubProfile)
            
            return userProfile
        } catch {
            await application.logger.store("Error during download profile: '\(activityPubProfile)'.", error, on: application)
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
    
    private func searchByStatuses(query: String, on request: Request) async -> SearchResultDto {
        // For empty query we don't have to retrieve anything from database and return empty list.
        if query.isEmpty {
            return SearchResultDto(statuses: [])
        }
        
        let id = self.getIdFromQuery(from: query)
        let statuses = try? await Status.query(on: request.db)
            .group(.or) { group in
                group
                    .filter(id: id)
                    .filter(\.$note ~~ query)
                    .filter(\.$activityPubId == query)
                    .filter(\.$activityPubUrl == query)
            }
            .filter(\.$visibility == .public)
            .filter(\.$replyToStatus.$id == nil)
            .with(\.$user)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$mentions)
            .with(\.$category)
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: 1, per: 20))
        
        guard let statuses else {
            return SearchResultDto(statuses: [])
        }
        
        let statusesService = request.application.services.statusesService
        let statusesDtos = await statusesService.convertToDtos(on: request, statuses: statuses.items)
        
        return SearchResultDto(statuses: statusesDtos)
    }
        
    private func searchByHashtags(query: String, on request: Request) async -> SearchResultDto {
        // For empty query we don't have to retrieve anything from database and return empty list.
        if query.isEmpty {
            return SearchResultDto(users: [])
        }
        
        let queryNormalized = query.uppercased()
        let hashtags = try? await TrendingHashtag.query(on: request.db)
            .filter(\.$hashtagNormalized ~~ queryNormalized)
            .filter(\.$trendingPeriod == .yearly)
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: 1, per: 100))
        
        guard let hashtags else {
            return SearchResultDto(hashtags: [])
        }
        
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        let hashtagDtos = await hashtags.items.asyncMap { hashtag in
            HashtagDto(url: "\(baseAddress)/tags/\(hashtag.hashtag)", name: hashtag.hashtag, amount: hashtag.amount)
        }
        
        return SearchResultDto(hashtags: hashtagDtos)
    }
    
    private func searchByLocalUsers(query: String, on request: Request) async -> SearchResultDto {
        // For empty query we don't have to retrieve anything from database and return empty list.
        if query.isEmpty {
            return SearchResultDto(users: [])
        }
        
        let queryNormalized = query.uppercased()
        let userNameNormalized = self.getUserNameFromQuery(from: query)
        let id = self.getIdFromQuery(from: query)

        let users = try? await User.query(on: request.db)
            .group(.or) { group in
                group
                    .filter(id: id)
                    .filter(userName: userNameNormalized)
                    .filter(\.$queryNormalized ~~ queryNormalized)
                    .filter(\.$activityPubProfile == query)
                    .filter(\.$url == query)
            }
            .with(\.$flexiFields)
            .with(\.$roles)
            .sort(\.$followersCount, .descending)
            .paginate(PageRequest(page: 1, per: 20))

        // In case of error we have to return empty list.
        guard let users else {
            request.logger.notice("Issue during filtering local users.")
            return SearchResultDto(users: [])
        }
        
        let usersService = request.application.services.usersService
        let userDtos = await usersService.convertToDtos(on: request, users: users.items, attachSensitive: false)
                
        return SearchResultDto(users: userDtos)
    }
    
    private func searchByRemoteUsers(query: String, on request: Request) async -> SearchResultDto {
        // Get hostname from user query.
        guard let baseUrl = self.getBaseUrl(from: query) else {
            request.logger.notice("Base url cannot be parsed from user query: '\(query)'.")
            return SearchResultDto(users: [])
        }
        
        // Url cannot be mentioned in instance blocked domains.
        let isBlockedDomain = await self.existsInInstanceBlockedList(url: baseUrl, on: request)
        guard isBlockedDomain == false else {
            request.logger.notice("Base URL is listed in blocked instance domains: '\(query)'.")
            return SearchResultDto(users: [])
        }
        
        // Search user profile by remote webfinger.
        guard let activityPubProfile = await self.getActivityPubProfile(query: query, baseUrl: baseUrl, on: request.application) else {
            request.logger.warning("ActivityPub profile '\(query)' cannot be downloaded from: '\(baseUrl)'.")
            return SearchResultDto(users: [])
        }
        
        // Download user profile from remote server.
        return await self.downloadRemoteUser(activityPubProfile: activityPubProfile, on: request)
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
                let newUser = try await usersService.create(on: application,
                                                            basedOn: personProfile,
                                                            withAvatarFileName: profileIconFileName,
                                                            withHeaderFileName: profileImageFileName)

                return newUser
            } else {
                // If user exist then we have to update uhis account in internal database and return it.
                let updatedUser = try await usersService.update(user: userFromDb!,
                                                                on: application,
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
    
    private func getActivityPubProfile(query: String, baseUrl: URL, on application: Application) async -> String? {
        do {
            let activityPubClient = ActivityPubClient()
            
            // Download link to profile (HostMeta).
            guard let url = try await self.getActivityPubProfileLink(query: query, baseUrl: baseUrl) else {
                application.logger.warning("Error during search user: \(query) on host: \(baseUrl.absoluteString). Cannot calculate user profile.")
                return nil
            }

            // Download profile data (Webfinger).
            let webfingerResult = try await activityPubClient.webfinger(url: url)
            guard let activityPubProfile = webfingerResult.links.first(where: { $0.rel == "self" })?.href else {
                return nil
            }
            
            return activityPubProfile
        } catch {
            application.logger.warning("Error during downloading user profile '\(query)' from '\(baseUrl)'. Network error: '\(error.localizedDescription)'.")
            return nil
        }
    }
    
    private func getActivityPubProfileLink(query: String, baseUrl: URL) async throws -> URL? {
        let activityPubClient = ActivityPubClient()

        // First we have to download host meta where we have URL to webfinger.
        let hostMetaContent = try await activityPubClient.hostMeta(baseUrl: baseUrl)

        // Get url from returned XML or default one.
        var urlFromHostMeta = self.getWebfingerLink(from: hostMetaContent)
        if urlFromHostMeta == nil {
            urlFromHostMeta = baseUrl.absoluteString.deletingSuffix("/").appending("/.well-known/webfinger?resource={uri}")
        }
        
        guard let urlFromHostMeta else {
            return nil
        }
        
        // Search query shouldn't contains first (at) sign, e.g. johndoe@server.pl.
        let searchQuery = query.trimmingPrefix("@")
        
        // Replace {uri} with `searchQuery`.
        let urlString = urlFromHostMeta
            .replacingOccurrences(of: "%7Buri%7D", with: searchQuery)
            .replacingOccurrences(of: "{uri}", with: searchQuery)

        guard let url = URL(string: urlString) else {
            return nil
        }
        
        return url
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
        if query.starts(with: "http://") || query.starts(with: "https://") {
            return true
        }
        
        let queryParts = query.split(separator: "@")
        if queryParts.count <= 1 {
            return true
        }
        
        let applicationSettings = request.application.settings.cached
        let domain = applicationSettings?.domain ?? ""

        if queryParts[1].uppercased() == domain.uppercased() {
            return true
        }
        
        return false
    }
    
    func getWebfingerLink(from xml: String?) -> String? {
        guard let xml else {
            return nil
        }
        
        // Parse string as a XML document.
        guard let html = try? SwiftSoup.parse(xml) else {
            return nil
        }
        
        // Find all links with rel="lrdd".
        guard let links = try? html.select("link[rel*=lrdd]") else {
            return nil
        }

        // Iterate throught links and check if we have one with 'application/json' type.
        var anyTemplate: String? = nil
        for link in links.array() {
            let type = (try? link.attr("type")) ?? ""
            let template = try? link.attr("template")
            
            if type.isEmpty == true || type == "application/json" {
                return template
            } else {
                anyTemplate = template
            }
        }
        
        return anyTemplate
    }
    

    
    private func getIdFromQuery(from query: String) -> Int64? {
        let components = query.components(separatedBy: "/")
        guard let stringId = components.last else {
            return nil
        }
        
        return Int64(stringId)
    }
    
    private func getUserNameFromQuery(from query: String) -> String? {
        let components = query.components(separatedBy: "/")
        guard let userName = components.last else {
            return nil
        }
        
        return userName
            .trimmingCharacters(in: .init(charactersIn: "@"))
            .uppercased()
    }
}
