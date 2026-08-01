//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Queues
import ActivityPubKit
import SwiftSoup

extension Application.Services {
    struct ActivityPubDownloadUserServiceKey: StorageKey {
        typealias Value = ActivityPubDownloadUserServiceType
    }

    var activityPubDownloadUserService: ActivityPubDownloadUserServiceType {
        get {
            self.application.storage[ActivityPubDownloadUserServiceKey.self] ?? ActivityPubDownloadUserService()
        }
        nonmutating set {
            self.application.storage[ActivityPubDownloadUserServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ActivityPubDownloadUserServiceType: Sendable {

    /// Downloads a remote ActivityPub `Person` document by profile URL.
    ///
    /// The method signs the request with the default system user's private key, because some remote instances require
    /// signed ActivityPub requests before returning actor data.
    ///
    /// - Parameters:
    ///   - activityPubProfile: The ActivityPub profile URL of the person to download.
    ///   - context: The execution context providing services and database access.
    /// - Returns: The downloaded `PersonDto` object.
    /// - Throws: Configuration, URL parsing, or network errors when the profile cannot be downloaded.
    func downloadPerson(activityPubProfile: String, on context: ExecutionContext) async throws -> PersonDto
    
    /// Returns a remote user by username, downloading it only when it does not exist in the local database.
    ///
    /// The method first checks the local database by username and immediately returns that user without verifying freshness.
    /// When the user is missing, it resolves the ActivityPub profile through WebFinger and then downloads or refreshes
    /// the remote profile through ``downloadIfNeeded(activityPubProfile:on:)``.
    ///
    /// - Parameters:
    ///   - userName: The ActivityPub username (for example, `user@domain`) to resolve.
    ///   - context: The execution context for database and services.
    /// - Returns: The local or downloaded user object, or `nil` when the profile cannot be resolved or downloaded.
    /// - Throws: Database errors or errors from the remote user download flow.
    func downloadIfMissing(userName: String, on context: ExecutionContext) async throws -> User?

    /// Returns a remote user by ActivityPub profile URL, using the local freshness cache when possible.
    ///
    /// The method first checks the local database by ActivityPub profile URL. Local users are always returned as-is.
    /// Remote users are returned from the database when their stored copy is fresh enough; stale or missing remote users
    /// are refreshed from the remote server and saved locally.
    ///
    /// - Parameters:
    ///   - activityPubProfile: The ActivityPub profile URL of the user to download or refresh.
    ///   - context: The execution context providing services and database access.
    /// - Returns: The existing, refreshed, or newly created `User` object, or `nil` when the profile cannot be downloaded.
    /// - Throws: Database errors or errors from the remote user refresh flow.
    func downloadIfNeeded(activityPubProfile: String, on context: ExecutionContext) async throws -> User?

    /// Refreshes a remote user and saves the latest version locally, bypassing freshness cache.
    ///
    /// The method still returns local users unchanged, because local profiles must not be overwritten from remote data.
    /// For remote users, it downloads the `Person` document and profile images, then updates the existing database record
    /// or creates a new one. If the remote profile cannot be downloaded or saved, the previously stored database value is returned.
    ///
    /// - Parameters:
    ///   - activityPubProfile: The URL of the user's ActivityPub profile.
    ///   - context: The execution context for database and services.
    /// - Returns: The refreshed user object or existing database value if refresh fails.
    /// - Throws: An error if local database lookup fails.
    func refreshRemoteUser(activityPubProfile: String, on context: ExecutionContext) async throws -> User?

    /// Resolves an ActivityPub profile URL for a username.
    ///
    /// The method extracts the remote instance base URL from the username, skips resolution when that instance is blocked,
    /// and then uses WebFinger to find the ActivityPub actor profile URL.
    ///
    /// - Parameters:
    ///   - userName: The ActivityPub username (for example, `user@domain`).
    ///   - context: The execution context for database and services.
    /// - Returns: The ActivityPub profile URL, or `nil` when the username cannot be parsed, the domain is blocked, or WebFinger fails.
    func resolveActivityPubProfile(userName: String, on context: ExecutionContext) async -> String?

    /// Resolves an ActivityPub profile URL for a username on the specified remote instance.
    ///
    /// The method discovers the WebFinger endpoint from host-meta when available, falls back to the default WebFinger URL,
    /// and returns the profile URL from the `self` link in the WebFinger response.
    ///
    /// - Parameters:
    ///   - userName: The ActivityPub username (for example, `user@domain`).
    ///   - baseUrl: The remote instance base URL used for host-meta and WebFinger discovery.
    ///   - context: The execution context for database and services.
    /// - Returns: The ActivityPub profile URL, or `nil` when discovery or WebFinger resolution fails.
    func resolveActivityPubProfile(userName: String, baseUrl: URL, on context: ExecutionContext) async -> String?
}

final class ActivityPubDownloadUserService: ActivityPubDownloadUserServiceType {

    public func downloadPerson(activityPubProfile: String, on context: ExecutionContext) async throws -> PersonDto {
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
        return try await activityPubClient.person(id: activityPubProfile, activityPubProfile: defaultSystemUser.activityPubProfile)
    }

    public func downloadIfMissing(userName: String, on context: ExecutionContext) async throws -> User? {
        let usersService = context.services.usersService

        // Check if we already have user in local database.
        let user = try await usersService.get(userName: userName, on: context.db)
        if let user {
            return user
        }

        // We have to download first URL to user data from webfinger.
        let activityPubProfile = await self.resolveActivityPubProfile(userName: userName, on: context)
        guard let activityPubProfile else {
            return nil
        }

        // Download remote user data to local database.
        let userFromRemote = try await self.downloadIfNeeded(activityPubProfile: activityPubProfile, on: context)
        return userFromRemote
    }

    public func downloadIfNeeded(activityPubProfile: String, on context: ExecutionContext) async throws -> User? {
        let usersService = context.services.usersService

        let userFromDatabase = try await usersService.get(activityPubProfile: activityPubProfile, on: context.db)
        if let userFromDatabase, userFromDatabase.isLocal == true || max((userFromDatabase.updatedAt ?? Date.distantPast), (userFromDatabase.createdAt ?? Date.distantPast)) > Date.yesterday {
            return userFromDatabase
        }

        return try await self.refreshRemoteUser(activityPubProfile: activityPubProfile, on: context)
    }

    public func refreshRemoteUser(activityPubProfile: String, on context: ExecutionContext) async throws -> User? {
        let usersService = context.services.usersService

        let userFromDatabase = try await usersService.get(activityPubProfile: activityPubProfile, on: context.db)
        if let userFromDatabase, userFromDatabase.isLocal {
            return userFromDatabase
        }

        guard let personProfile = await self.downloadPersonSuppressingErrors(activityPubProfile: activityPubProfile, on: context) else {
            context.logger.warning("ActivityPub profile cannot be downloaded: '\(activityPubProfile)'.")
            return userFromDatabase
        }

        // Download profile icon from remote server.
        let profileIconFileName = await usersService.downloadProfileImage(personProfile: personProfile, on: context)

        // Download profile header from remote server.
        let profileImageFileName = await usersService.downloadHeaderImage(personProfile: personProfile, on: context)

        // Update profile in internal database and return it.
        guard let user = await self.update(personProfile: personProfile,
                                           profileIconFileName: profileIconFileName,
                                           profileImageFileName: profileImageFileName,
                                           on: context) else {
            // When we cannot update new user profile into database we have to return existing user data.
            return userFromDatabase
        }

        // Downlaod updated flexi fields.
        let flexiFieldService = context.services.flexiFieldService
        let flexiFields = try? await flexiFieldService.getFlexiFields(for: user.requireID(), on: context.db)

        // Enqueue job for flexi field URL validator.
        if let flexiFields {
            try? await flexiFieldService.dispatchUrlValidator(flexiFields: flexiFields, on: context)
        }

        return user
    }

    public func resolveActivityPubProfile(userName: String, on context: ExecutionContext) async -> String? {
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
        guard let activityPubProfile = await self.resolveActivityPubProfile(userName: userName, baseUrl: baseUrl, on: context) else {
            context.logger.warning("ActivityPub profile '\(userName)' cannot be downloaded from: '\(baseUrl)'.")
            return nil
        }

        return activityPubProfile
    }

    public func resolveActivityPubProfile(userName: String, baseUrl: URL, on context: ExecutionContext) async -> String? {
        do {
            let activityPubClient = ActivityPubClient()

            // Download link to profile (HostMeta).
            guard let url = try await self.getActivityPubProfileLink(userName: userName, baseUrl: baseUrl) else {
                context.logger.warning("Error during search user: \(userName) on host: \(baseUrl.absoluteString). Cannot calculate user profile.")
                return nil
            }

            // Download profile data (Webfinger).
            let webfingerResult = try await activityPubClient.webfinger(url: url)
            guard let activityPubProfile = webfingerResult.links.first(where: { $0.rel == "self" })?.href else {
                return nil
            }

            return activityPubProfile
        } catch {
            context.logger.warning("Error during downloading user profile '\(userName)' from '\(baseUrl)'. Network error: '\(error.localizedDescription)'.")
            return nil
        }
    }

    private func downloadPersonSuppressingErrors(activityPubProfile: String, on context: ExecutionContext) async -> PersonDto? {
        do {
            let userProfile = try await self.downloadPerson(activityPubProfile: activityPubProfile, on: context)
            return userProfile
        } catch {
            await context.logger.store("Error during download profile: '\(activityPubProfile)'.", error, on: context.application)
        }

        return nil
    }

    private func getActivityPubProfileLink(userName: String, baseUrl: URL) async throws -> URL? {
        let activityPubClient = ActivityPubClient()

        // First we have to download host meta where we have URL to webfinger (when error occurs, like 404 we can assume default webfinger url).
        let hostMetaContent = try? await activityPubClient.hostMeta(baseUrl: baseUrl)

        // Get url from returned XML or default one.
        var urlFromHostMeta = self.getWebfingerLink(from: hostMetaContent)
        if urlFromHostMeta == nil {
            urlFromHostMeta = baseUrl.absoluteString.deletingSuffix("/").appending("/.well-known/webfinger?resource={uri}")
        }

        guard let urlFromHostMeta else {
            return nil
        }

        // Search query shouldn't contains first (at) sign, e.g. johndoe@server.pl.
        let userNameQuery = "acct:" + userName.trimmingPrefix("@")

        // Replace {uri} with `searchQuery`.
        let urlString = urlFromHostMeta
            .replacingOccurrences(of: "%7Buri%7D", with: userNameQuery)
            .replacingOccurrences(of: "{uri}", with: userNameQuery)

        guard let url = URL(string: urlString) else {
            return nil
        }

        return url
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

    private func update(personProfile: PersonDto, profileIconFileName: String?, profileImageFileName: String?, on context: ExecutionContext) async -> User? {
        do {
            let usersService = context.services.usersService
            let userFromDb = try await usersService.get(activityPubProfile: personProfile.id, on: context.db)

            if let userFromDb {
                guard userFromDb.isLocal == false else {
                    context.logger.warning("Cannot update local user based on remote profile: \(personProfile.id)")
                    return userFromDb
                }

                // If user exist then we have to update uhis account in internal database and return it.
                let updatedUser = try await usersService.update(user: userFromDb,
                                                                basedOn: personProfile,
                                                                withAvatarFileName: profileIconFileName,
                                                                withHeaderFileName: profileImageFileName,
                                                                on: context)

                return updatedUser
            } else {
                // If user not exist we have to create his account in internal database and return it.
                let newUser = try await usersService.create(basedOn: personProfile,
                                                            withAvatarFileName: profileIconFileName,
                                                            withHeaderFileName: profileImageFileName,
                                                            on: context)

                return newUser
            }
        } catch {
            context.logger.error("Error during creating/updating remote user: '\(personProfile.id)' in local database: '\(error.localizedDescription)', error: \(error).")
            return nil
        }
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
}
