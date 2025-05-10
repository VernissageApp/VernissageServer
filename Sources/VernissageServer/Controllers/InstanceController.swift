//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension InstanceController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("instance")
    
    func boot(routes: RoutesBuilder) throws {
        let instanceGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(InstanceController.uri)
        
        instanceGroup
            .grouped(EventHandlerMiddleware(.instance))
            .grouped(CacheControlMiddleware(.public()))
            .get(use: instance)
    }
}

/// Controller which expose information about specific instance configuration.
///
/// > Important: Base controller URL: `/api/v1/instance`.
struct InstanceController {
    
    /// Exposing information about Vernissage instance.
    ///
    /// An endpoint to learn about the basic configuration of an instance.
    /// It returns such information as rules, file size limits, status lengths, etc.
    ///
    /// > Important: Endpoint URL: `/api/v1/instance`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/instance" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```
    /// {
    ///     "configuration": {
    ///         "attachments": {
    ///             "imageSizeLimit": 10485760,
    ///             "supportedMimeTypes": [
    ///                 "image/png",
    ///                 "image/jpeg"
    ///             ]
    ///         },
    ///         "statuses": {
    ///             "charactersReservedPerUrl": 23,
    ///             "maxCharacters": 500,
    ///             "maxMediaAttachments": 4
    ///         }
    ///     },
    ///     "contact": { ... },
    ///     "description": "Official Vernissage instance.",
    ///     "email": "info@vernissage.photos",
    ///     "languages": [
    ///         "en"
    ///     ],
    ///     "registrationByApprovalOpened": false,
    ///     "registrationByInvitationsOpened": true,
    ///     "registrationOpened": false,
    ///     "rules": [
    ///         {
    ///             "id": 1,
    ///             "text": "Pornography is forbidden."
    ///         },
    ///         {
    ///             "id": 2,
    ///             "text": "Sexually explicit or violent media must be marked as sensitive when posting."
    ///         }
    ///     ],
    ///     "stats": {
    ///         "domainCount": 1,
    ///         "statusCount": 848,
    ///         "userCount": 176
    ///     },
    ///     "thumbnail": "",
    ///     "title": "Vernissage",
    ///     "uri": "https://vernissage.photos",
    ///     "version": "1.0.0-alpha1"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about Vernissage instance.
    @Sendable
    func instance(request: Request) async throws -> InstanceDto {
        let instanceCacheKey = String(describing: InstanceDto.self)

        if let instanceFromCache: InstanceDto = try? await request.cache.get(instanceCacheKey) {
            return instanceFromCache
        }
        
        let appplicationSettings = request.application.settings.cached
        let usersService = request.application.services.usersService
        let statusesService = request.application.services.statusesService
        
        let userCount =  try await usersService.count(sinceLastLoginDate: nil, on: request.db)
        let statusCount = try await statusesService.count(onlyComments: false, on: request.db)

        let rules = try await Rule.query(on: request.db).sort(\.$order).all()
        let contactUser = try await self.getContactUser(appplicationSettings: appplicationSettings, on: request)
        
        let instanceDto = InstanceDto(
            uri: appplicationSettings?.baseAddress ?? "",
            title: appplicationSettings?.webTitle ?? "",
            description: appplicationSettings?.webDescription ?? "",
            longDescription: appplicationSettings?.webLongDescription ?? "",
            email: appplicationSettings?.webEmail ?? "",
            version: Constants.version,
            thumbnail: appplicationSettings?.webThumbnail ?? "",
            languages: appplicationSettings?.webLanguages.split(separator: ",").map({ String($0) }) ?? [],
            rules: rules.map({ SimpleRuleDto(id: $0.order, text: $0.text) }),
            registrationOpened: appplicationSettings?.isRegistrationOpened ?? false,
            registrationByApprovalOpened: appplicationSettings?.isRegistrationByApprovalOpened ?? false,
            registrationByInvitationsOpened: appplicationSettings?.isRegistrationByInvitationsOpened ?? false,
            configuration: ConfigurationDto(
                statuses: ConfigurationStatusesDto(maxCharacters: appplicationSettings?.maxCharacters ?? Constants.statusMaxCharacters,
                                                   maxMediaAttachments: appplicationSettings?.maxMediaAttachments ?? Constants.statusMaxMediaAttachments,
                                                   charactersReservedPerUrl: Constants.statusCharactersReservedPerUrl),
                attachments: ConfigurationAttachmentsDto(supportedMimeTypes: ["image/png", "image/jpeg"],
                                                         imageSizeLimit: appplicationSettings?.imageSizeLimit ?? Constants.imageSizeLimit)
            ),
            stats: InstanceStatisticsDto(userCount: userCount,
                                         statusCount: statusCount,
                                         domainCount: 1),
            contact: contactUser)
        
        try? await request.cache.set(instanceCacheKey, to: instanceDto, expiresIn: .minutes(10))
        return instanceDto
    }
    
    private func getContactUser(appplicationSettings: ApplicationSettings?, on request: Request) async throws -> UserDto? {
        guard let contactUserId = appplicationSettings?.webContactUserId.toId() else {
            return nil
        }
        
        let usersService = request.application.services.usersService
        guard let user = try await usersService.get(id: contactUserId, on: request.db) else {
            return nil
        }
                
        let userDto = await usersService.convertToDto(user: user,
                                                      flexiFields: user.flexiFields,
                                                      roles: nil,
                                                      attachSensitive: false,
                                                      attachFeatured: false,
                                                      on: request.executionContext)

        return userDto
    }
}
