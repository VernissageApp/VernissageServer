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
    func search(query: String, searchType: SearchTypeDto, on context: ExecutionContext) async throws -> SearchResultDto
    func downloadRemoteUser(userName: String, on context: ExecutionContext) async throws -> User?
    func downloadRemoteUser(activityPubProfile: String, on context: ExecutionContext) async throws -> User?
    func getRemoteActivityPubProfile(userName: String, on context: ExecutionContext) async -> String?
}

/// A service for searching in the local and remote system.
final class SearchService: SearchServiceType {
    func search(query: String, searchType: SearchTypeDto, on context: ExecutionContext) async throws -> SearchResultDto {
        let queryWithoutPrefix = String(query.trimmingPrefix("@"))
        
        switch searchType {
        case .users:
            return await self.searchByUsers(query: queryWithoutPrefix, on: context)
        case .statuses:
            return await self.searchByStatuses(query: queryWithoutPrefix, tryToDownloadRemote: true, on: context)
        case .hashtags:
            return await self.searchByHashtags(query: queryWithoutPrefix, on: context)
        }
    }
    
    func downloadRemoteUser(userName: String, on context: ExecutionContext) async throws -> User? {
        let usersService = context.services.usersService

        // Check if we already have user in local database.
        let user = try await usersService.get(userName: userName, on: context.db)
        if let user {
            return user
        }

        // We have to download first URL to user data from webfinger.
        let activityPubProfile = await self.getRemoteActivityPubProfile(userName: userName, on: context)
        guard let activityPubProfile else {
            return nil
        }
        
        // Download remote user data to local database.
        let userFromRemote = try await self.downloadRemoteUser(activityPubProfile: activityPubProfile, on: context)
        return userFromRemote
    }
    
    func downloadRemoteUser(activityPubProfile: String, on context: ExecutionContext) async throws -> User? {
        let usersService = context.services.usersService
        
        let userFromDatabase = try await usersService.get(activityPubProfile: activityPubProfile, on: context.db)
        if let userFromDatabase, max((userFromDatabase.updatedAt ?? Date.distantPast), (userFromDatabase.createdAt ?? Date.distantPast)) > Date.yesterday {
            return userFromDatabase
        }
        
        guard let personProfile = await self.downloadProfile(activityPubProfile: activityPubProfile, context: context) else {
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
                                     on: context)
        
        if let user {
            // Downlaod updated flexi fields.
            let flexiFieldService = context.services.flexiFieldService
            let flexiFields = try? await flexiFieldService.getFlexiFields(for: user.requireID(), on: context.db)
            
            // Enqueue job for flexi field URL validator.
            if let flexiFields {
                try? await flexiFieldService.dispatchUrlValidator(flexiFields: flexiFields, on: context)
            }
        }
        
        return user
    }
    
    func getRemoteActivityPubProfile(userName: String, on context: ExecutionContext) async -> String? {
        // Get hostname from user query.
        guard let baseUrl = self.getBaseUrlFrom(query: userName) else {
            context.logger.notice("Base url cannot be parsed from user name: '\(userName)'.")
            return nil
        }
        
        // Url cannot be mentioned in instance blocked domains.
        let isBlockedDomain = await self.existsInInstanceBlockedList(url: baseUrl, on: context)
        guard isBlockedDomain == false else {
            context.logger.notice("Base URL is listed in blocked instance domains: '\(userName)'.")
            return nil
        }
        
        // Search user profile by remote webfinger.
        guard let activityPubProfile = await self.getActivityPubProfile(query: userName, baseUrl: baseUrl, on: context) else {
            context.logger.warning("ActivityPub profile '\(userName)' cannot be downloaded from: '\(baseUrl)'.")
            return nil
        }
        
        return activityPubProfile
    }
    
    private func downloadProfile(activityPubProfile: String, context: ExecutionContext) async -> PersonDto? {
        do {
            let usersService = context.services.usersService
            guard let defaultSystemUser = try await usersService.getDefaultSystemUser(on: context.db) else {
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
            await context.logger.store("Error during download profile: '\(activityPubProfile)'.", error, on: context.application)
        }
        
        return nil
    }
    
    private func searchByUsers(query: String, on context: ExecutionContext) async -> SearchResultDto {
        if self.isLocalSearch(query: query, on: context) {
            return await self.searchByLocalUsers(query: query, on: context)
        } else {
            return await self.searchByRemoteUsers(query: query, on: context)
        }
    }
    
    private func searchByStatuses(query: String, tryToDownloadRemote: Bool, on context: ExecutionContext) async -> SearchResultDto {
        // For empty query we don't have to retrieve anything from database and return empty list.
        if query.isEmpty {
            return SearchResultDto(statuses: [])
        }
        
        let id = self.getIdFromQuery(from: query)
        let statuses = try? await Status.query(on: context.db)
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
                attachment.with(\.$originalHdrFile)
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
        
        // If the query contains url we can try to download status from remote server.
        if tryToDownloadRemote && self.shouldDownloadFromRemote(query: query, on: context) {
            return await self.searchByRemoteStatuses(activityPubUrl: query, on: context)
        }
        
        guard let statuses else {
            return SearchResultDto(statuses: [])
        }
        
        let statusesService = context.services.statusesService
        let statusesDtos = await statusesService.convertToDtos(statuses: statuses.items, on: context)
        
        return SearchResultDto(statuses: statusesDtos)
    }
        
    private func searchByHashtags(query: String, on context: ExecutionContext) async -> SearchResultDto {
        // For empty query we don't have to retrieve anything from database and return empty list.
        if query.isEmpty {
            return SearchResultDto(users: [])
        }
        
        let queryNormalized = query.uppercased()
        let hashtags = try? await TrendingHashtag.query(on: context.db)
            .filter(\.$hashtagNormalized ~~ queryNormalized)
            .filter(\.$trendingPeriod == .yearly)
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: 1, per: 100))
        
        guard let hashtags else {
            return SearchResultDto(hashtags: [])
        }
        
        let baseAddress = context.settings.cached?.baseAddress ?? ""
        let hashtagDtos = await hashtags.items.asyncMap { hashtag in
            HashtagDto(url: "\(baseAddress)/tags/\(hashtag.hashtag)", name: hashtag.hashtag, amount: hashtag.amount)
        }
        
        return SearchResultDto(hashtags: hashtagDtos)
    }
    
    private func searchByLocalUsers(query: String, on context: ExecutionContext) async -> SearchResultDto {
        // For empty query we don't have to retrieve anything from database and return empty list.
        if query.isEmpty {
            return SearchResultDto(users: [])
        }
        
        let queryNormalized = query.uppercased()
        let userNameNormalized = self.getUserNameFromQuery(from: query)
        let id = self.getIdFromQuery(from: query)

        let users = try? await User.query(on: context.db)
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

        // If the query contains url we can try to download user from remote server.
        if self.shouldDownloadFromRemote(query: query, on: context) {
            return await self.searchByRemoteUsers(activityPubProfileUrl: query, on: context)
        }
        
        // In case that we didn't found any user we have to return empty list.
        guard let users else {
            context.logger.notice("Issue during filtering local users.")
            return SearchResultDto(users: [])
        }
        
        let usersService = context.services.usersService
        let userDtos = await usersService.convertToDtos(users: users.items, attachSensitive: false, on: context)
                
        return SearchResultDto(users: userDtos)
    }
    
    private func searchByRemoteUsers(query: String, on context: ExecutionContext) async -> SearchResultDto {
        // Get hostname from user query.
        guard let baseUrl = self.getBaseUrlFrom(query: query) else {
            context.logger.notice("Base url cannot be parsed from user query: '\(query)'.")
            return SearchResultDto(users: [])
        }
        
        // Url cannot be mentioned in instance blocked domains.
        let isBlockedDomain = await self.existsInInstanceBlockedList(url: baseUrl, on: context)
        guard isBlockedDomain == false else {
            context.logger.notice("Base URL is listed in blocked instance domains: '\(query)'.")
            return SearchResultDto(users: [])
        }
        
        // Search user profile by remote webfinger.
        guard let activityPubProfile = await self.getActivityPubProfile(query: query, baseUrl: baseUrl, on: context) else {
            context.logger.warning("ActivityPub profile '\(query)' cannot be downloaded from: '\(baseUrl)'.")
            return SearchResultDto(users: [])
        }
        
        // Download user profile from remote server.
        return await self.searchUserOnRemoteServer(activityPubProfile: activityPubProfile, on: context)
    }
    
    private func searchByRemoteUsers(activityPubProfileUrl: String, on context: ExecutionContext) async -> SearchResultDto {
        // Get hostname from user query.
        guard let baseUrl = self.getBaseUrlFrom(url: activityPubProfileUrl) else {
            context.logger.notice("Base url cannot be parsed from user query: '\(activityPubProfileUrl)'.")
            return SearchResultDto(users: [])
        }
        
        // Url cannot be mentioned in instance blocked domains.
        let isBlockedDomain = await self.existsInInstanceBlockedList(url: baseUrl, on: context)
        guard isBlockedDomain == false else {
            context.logger.notice("Base URL is listed in blocked instance domains: '\(activityPubProfileUrl)'.")
            return SearchResultDto(users: [])
        }
        
        // Download user profile from remote server.
        return await self.searchUserOnRemoteServer(activityPubProfile: activityPubProfileUrl, on: context)
    }
    
    private func searchByRemoteStatuses(activityPubUrl: String, on context: ExecutionContext) async -> SearchResultDto {
        // Get hostname from user query.
        guard let baseUrl = self.getBaseUrlFrom(url: activityPubUrl) else {
            context.logger.notice("Base url cannot be parsed from user query: '\(activityPubUrl)'.")
            return SearchResultDto(users: [])
        }
        
        // Url cannot be mentioned in instance blocked domains.
        let isBlockedDomain = await self.existsInInstanceBlockedList(url: baseUrl, on: context)
        guard isBlockedDomain == false else {
            context.logger.notice("Base URL is listed in blocked instance domains: '\(activityPubUrl)'.")
            return SearchResultDto(users: [])
        }
        
        // Download status from remote server.
        do {
            let activityPubService = context.services.activityPubService
            let downloadedStatus = try await activityPubService.downloadStatus(activityPubId: activityPubUrl, on: context)
            
            return await self.searchByStatuses(query: downloadedStatus.activityPubUrl, tryToDownloadRemote: false, on: context)
        }
        catch {
            await context.logger.store("Downloading status '\(activityPubUrl)' from remote server failed.", error, on: context.application)
        }
        
        return SearchResultDto(users: [])
    }
    
    private func searchUserOnRemoteServer(activityPubProfile: String, on context: ExecutionContext) async -> SearchResultDto {
        guard let personProfile = await self.downloadProfile(activityPubProfile: activityPubProfile, context: context) else {
            context.logger.warning("ActivityPub profile cannot be downloaded: '\(activityPubProfile)'.")
            return SearchResultDto(users: [])
        }
        
        // Download profile icon from remote server.
        let profileIconFileName = await self.downloadProfileImage(personProfile: personProfile, on: context)
        
        // Download profile header from remote server.
        let profileImageFileName = await self.downloadHeaderImage(personProfile: personProfile, on: context)
        
        // Update profile in internal database and return it.
        guard let user = await self.update(personProfile: personProfile,
                                           profileIconFileName: profileIconFileName,
                                           profileImageFileName: profileImageFileName,
                                           on: context) else {
            return SearchResultDto(users: [])
        }
        
        let flexiFieldService = context.services.flexiFieldService
        let usersService = context.services.usersService
        
        let flexiFields = try? await flexiFieldService.getFlexiFields(for: user.requireID(), on: context.db)
        let userDto = await usersService.convertToDto(user: user, flexiFields: flexiFields, roles: nil, attachSensitive: false, attachFeatured: false, on: context)
        
        // Enqueue job for flexi field URL validator.
        if let flexiFields {
            try? await flexiFieldService.dispatchUrlValidator(flexiFields: flexiFields, on: context)
        }
        
        return SearchResultDto(users: [userDto])
    }
    
    private func downloadProfileImage(personProfile: PersonDto, on context: ExecutionContext) async -> String? {
        guard let icon = personProfile.icon else {
            return nil
        }
        
        if icon.url.isEmpty == false {
            let storageService = context.services.storageService
            let fileName = try? await storageService.dowload(url: icon.url, on: context)
            context.logger.info("Profile icon has been downloaded and saved: '\(fileName ?? "<unknown>")'.")
            
            return fileName
        }
        
        return nil
    }
    
    private func downloadHeaderImage(personProfile: PersonDto, on context: ExecutionContext) async -> String? {
        guard let image = personProfile.image else {
            return nil
        }
        
        if image.url.isEmpty == false {
            let storageService = context.services.storageService
            let fileName = try? await storageService.dowload(url: image.url, on: context)
            context.logger.info("Header image has been downloaded and saved: '\(fileName ?? "<unknown>")'.")
            
            return fileName
        }
        
        return nil
    }
    
    private func update(personProfile: PersonDto, profileIconFileName: String?, profileImageFileName: String?, on context: ExecutionContext) async -> User? {
        do {
            let usersService = context.services.usersService
            let userFromDb = try await usersService.get(activityPubProfile: personProfile.id, on: context.db)
            
            // If user not exist we have to create his account in internal database and return it.
            if userFromDb == nil {
                let newUser = try await usersService.create(basedOn: personProfile,
                                                            withAvatarFileName: profileIconFileName,
                                                            withHeaderFileName: profileImageFileName,
                                                            on: context)

                return newUser
            } else {
                // If user exist then we have to update uhis account in internal database and return it.
                let updatedUser = try await usersService.update(user: userFromDb!,
                                                                basedOn: personProfile,
                                                                withAvatarFileName: profileIconFileName,
                                                                withHeaderFileName: profileImageFileName,
                                                                on: context)

                return updatedUser
            }
        } catch {
            context.logger.warning("Error during creating/updating remote user: '\(personProfile.id)' in local database: '\(error.localizedDescription)'.")
            return nil
        }
    }
    
    private func getActivityPubProfile(query: String, baseUrl: URL, on context: ExecutionContext) async -> String? {
        do {
            let activityPubClient = ActivityPubClient()
            
            // Download link to profile (HostMeta).
            guard let url = try await self.getActivityPubProfileLink(query: query, baseUrl: baseUrl) else {
                context.logger.warning("Error during search user: \(query) on host: \(baseUrl.absoluteString). Cannot calculate user profile.")
                return nil
            }

            // Download profile data (Webfinger).
            let webfingerResult = try await activityPubClient.webfinger(url: url)
            guard let activityPubProfile = webfingerResult.links.first(where: { $0.rel == "self" })?.href else {
                return nil
            }
            
            return activityPubProfile
        } catch {
            context.logger.warning("Error during downloading user profile '\(query)' from '\(baseUrl)'. Network error: '\(error.localizedDescription)'.")
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
    
    private func existsInInstanceBlockedList(url: URL, on context: ExecutionContext) async -> Bool {
        let instanceBlockedDomainsService = context.services.instanceBlockedDomainsService
        let exists = try? await instanceBlockedDomainsService.exists(url: url, on: context.db)
        
        return exists ?? false
    }
        
    private func getBaseUrlFrom(query: String) -> URL? {
        let domainFromQuery = query.split(separator: "@").last ?? ""
        return URL(string: "https://\(domainFromQuery)")
    }
    
    private func getBaseUrlFrom(url: String) -> URL? {
        let uri = URI(string: url)
        guard let domainFromQuery = uri.host?.lowercased() else {
            return nil
        }

        return URL(string: "https://\(domainFromQuery)")
    }
    
    private func shouldDownloadFromRemote(query: String, on context: ExecutionContext) -> Bool {
        let applicationSettings = context.settings.cached
        let domain = applicationSettings?.domain ?? ""

        if query.starts(with: "https://\(domain)") {
            return false
        }
        
        if query.starts(with: "http://") || query.starts(with: "https://") {
            return true
        }
        
        return false
    }
    
    private func isLocalSearch(query: String, on context: ExecutionContext) -> Bool {
        if query.starts(with: "http://") || query.starts(with: "https://") {
            return true
        }
        
        let queryParts = query.split(separator: "@")
        if queryParts.count <= 1 {
            return true
        }
        
        let applicationSettings = context.settings.cached
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
