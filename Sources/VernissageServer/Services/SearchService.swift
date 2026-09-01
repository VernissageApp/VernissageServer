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
import SQLKit

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
    /// Executes a search query based on the specified type in the local and remote system.
    ///
    /// - Parameters:
    ///   - query: The search string to process.
    ///   - searchType: The type of search (users, statuses, hashtags).
    ///   - context: The execution context for database and services.
    /// - Returns: The search result containing matched entities.
    /// - Throws: An error if the search fails.
    func search(query: String, searchType: SearchTypeDto, on context: ExecutionContext) async throws -> SearchResultDto
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
                    .filter(note: query)
                    .filter(\.$activityPubId == query)
                    .filter(\.$activityPubUrl == query)
            }
            .filter(\.$visibility ~~ [.public, .quietPublic])
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

        guard let statuses else {
            return SearchResultDto(statuses: [])
        }

        let statusesService = context.services.statusesService

        if statuses.items.isEmpty == false {
            let statusesDtos = await statusesService.convertToDtos(statuses: statuses.items, on: context)
            return SearchResultDto(statuses: statusesDtos)
        }

        // If the query contains url we can try to download status from remote server.
        if tryToDownloadRemote && self.shouldDownloadFromRemote(query: query, on: context) {
            return await self.searchByRemoteStatuses(activityPubUrl: query, on: context)
        }

        return SearchResultDto(statuses: [])
    }

    private func searchByHashtags(query: String, on context: ExecutionContext) async -> SearchResultDto {
        // For empty query we don't have to retrieve anything from database and return empty list.
        let queryWithoutPrefix = String(query.trimmingCharacters(in: .whitespacesAndNewlines).trimmingPrefix("#"))
        let queryNormalized = queryWithoutPrefix.uppercased()

        if queryNormalized.isEmpty {
            return SearchResultDto(hashtags: [])
        }

        guard let sqlDatabase = context.db as? SQLDatabase else {
            return SearchResultDto(hashtags: [])
        }

        let escapedQueryNormalized = queryNormalized
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        let queryPrefix = "\(escapedQueryNormalized)%"

        let hashtags = try? await sqlDatabase.raw("""
            SELECT
                (
                    SELECT \(ident: "candidate").\(ident: "hashtag")
                    FROM \(ident: StatusHashtag.schema) \(ident: "candidate")
                        INNER JOIN \(ident: Status.schema) \(ident: "candidateStatus")
                            ON \(ident: "candidateStatus").\(ident: "id") = \(ident: "candidate").\(ident: "statusId")
                    WHERE
                        \(ident: "candidate").\(ident: "hashtagNormalized") = \(ident: "sh").\(ident: "hashtagNormalized")
                        AND \(ident: "candidateStatus").\(ident: "visibility") IN (
                            \(bind: StatusVisibility.public.rawValue),
                            \(bind: StatusVisibility.quietPublic.rawValue)
                        )
                        AND \(ident: "candidateStatus").\(ident: "reblogId") IS NULL
                        AND \(ident: "candidateStatus").\(ident: "replyToStatusId") IS NULL
                    GROUP BY \(ident: "candidate").\(ident: "hashtag")
                    ORDER BY
                        (
                            lower(\(ident: "candidate").\(ident: "hashtag")) <> \(ident: "candidate").\(ident: "hashtag")
                            AND upper(\(ident: "candidate").\(ident: "hashtag")) <> \(ident: "candidate").\(ident: "hashtag")
                        ) DESC,
                        COUNT(*) DESC,
                        \(ident: "candidate").\(ident: "hashtag") ASC
                    LIMIT 1
                ) AS \(ident: "hashtag"),
                COUNT(*) AS \(ident: "amount")
            FROM \(ident: StatusHashtag.schema) \(ident: "sh")
                INNER JOIN \(ident: Status.schema) \(ident: "s")
                    ON \(ident: "s").\(ident: "id") = \(ident: "sh").\(ident: "statusId")
            WHERE
                \(ident: "sh").\(ident: "hashtagNormalized") LIKE \(bind: queryPrefix) ESCAPE \(literal: "\\")
                AND \(ident: "s").\(ident: "visibility") IN (
                    \(bind: StatusVisibility.public.rawValue),
                    \(bind: StatusVisibility.quietPublic.rawValue)
                )
                AND \(ident: "s").\(ident: "reblogId") IS NULL
                AND \(ident: "s").\(ident: "replyToStatusId") IS NULL
            GROUP BY \(ident: "sh").\(ident: "hashtagNormalized")
            ORDER BY
                CASE
                    WHEN \(ident: "sh").\(ident: "hashtagNormalized") = \(bind: queryNormalized) THEN 0
                    ELSE 1
                END,
                COUNT(*) DESC,
                \(ident: "sh").\(ident: "hashtagNormalized") ASC
            LIMIT 100
        """).all(decoding: HashtagSearchResult.self)

        guard let hashtags else {
            return SearchResultDto(hashtags: [])
        }

        let baseAddress = context.settings.cached?.baseAddress ?? ""
        let hashtagDtos = hashtags.map { hashtag in
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

        // In case that we didn't found any user we have to return empty list.
        guard let users else {
            context.logger.notice("Issue during filtering local users.")
            return SearchResultDto(users: [])
        }

        let usersService = context.services.usersService

        if users.items.isEmpty == false {
            let userDtos = await usersService.convertToDtos(users: users.items, attachSensitive: false, on: context)
            return SearchResultDto(users: userDtos)
        }

        // If the query contains url we can try to download user from remote server.
        if self.shouldDownloadFromRemote(query: query, on: context) {
            return await self.searchByRemoteUsers(activityPubProfileUrl: query, on: context)
        }

        return SearchResultDto(users: [])
    }

    private func searchByRemoteUsers(query: String, on context: ExecutionContext) async -> SearchResultDto {
        let activityPubDownloadUserService = context.services.activityPubDownloadUserService
        let flexiFieldService = context.services.flexiFieldService
        let usersService = context.services.usersService

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
        guard let activityPubProfile = await activityPubDownloadUserService.resolveActivityPubProfile(userName: query, baseUrl: baseUrl, on: context) else {
            context.logger.warning("ActivityPub profile '\(query)' cannot be downloaded from: '\(baseUrl)'.")
            return SearchResultDto(users: [])
        }

        // Download user profile from remote server.
        let user = try? await activityPubDownloadUserService.downloadIfNeeded(activityPubProfile: activityPubProfile, on: context)
        guard let user else {
            context.logger.warning("ActivityPub profile cannot be downloaded: '\(activityPubProfile)'.")
            return SearchResultDto(users: [])
        }

        // Download newest flexi fields.
        let flexiFields = try? await flexiFieldService.getFlexiFields(for: user.requireID(), on: context.db)

        // Create and return results.
        let userDto = await usersService.convertToDto(user: user, flexiFields: flexiFields, roles: nil, attachSensitive: false, attachFeatured: false, on: context)
        return SearchResultDto(users: [userDto])
    }

    private func searchByRemoteUsers(activityPubProfileUrl: String, on context: ExecutionContext) async -> SearchResultDto {
        let activityPubDownloadUserService = context.services.activityPubDownloadUserService
        let flexiFieldService = context.services.flexiFieldService
        let usersService = context.services.usersService

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
        let user = try? await activityPubDownloadUserService.downloadIfNeeded(activityPubProfile: activityPubProfileUrl, on: context)
        guard let user else {
            context.logger.warning("ActivityPub profile cannot be downloaded: '\(activityPubProfileUrl)'.")
            return SearchResultDto(users: [])
        }

        // Download newest flexi fields.
        let flexiFields = try? await flexiFieldService.getFlexiFields(for: user.requireID(), on: context.db)

        // Create and return results.
        let userDto = await usersService.convertToDto(user: user, flexiFields: flexiFields, roles: nil, attachSensitive: false, attachFeatured: false, on: context)
        return SearchResultDto(users: [userDto])
    }

    private func searchByRemoteStatuses(activityPubUrl: String, on context: ExecutionContext) async -> SearchResultDto {
        // Get hostname from user query.
        guard let baseUrl = self.getBaseUrlFrom(url: activityPubUrl) else {
            context.logger.notice("Base url cannot be parsed from user query: '\(activityPubUrl)'.")
            return SearchResultDto(statuses: [])
        }

        // Url cannot be mentioned in instance blocked domains.
        let isBlockedDomain = await self.existsInInstanceBlockedList(url: baseUrl, on: context)
        guard isBlockedDomain == false else {
            context.logger.notice("Base URL is listed in blocked instance domains: '\(activityPubUrl)'.")
            return SearchResultDto(statuses: [])
        }

        // Download status from remote server.
        do {
            let activityPubDownloadStatusService = context.services.activityPubDownloadStatusService
            let downloadedStatus = try await activityPubDownloadStatusService.download(activityPubId: activityPubUrl, on: context)

            return await self.searchByStatuses(query: downloadedStatus.activityPubUrl, tryToDownloadRemote: false, on: context)
        }
        catch {
            await context.logger.store("Downloading status '\(activityPubUrl)' from remote server failed.", error, on: context.application)
        }

        return SearchResultDto(statuses: [])
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
