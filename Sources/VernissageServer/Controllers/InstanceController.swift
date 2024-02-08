//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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
            .get(use: instance)
    }
}

/// Controller which expose information about specific instance configuration.
final class InstanceController {
    
    /// Exposing information about Vernissage instance.
    func instance(request: Request) async throws -> InstanceDto {
        let appplicationSettings = request.application.settings.cached
        
        let userCount = try await User.query(on: request.db).count()
        let statusCount = try await Status.query(on: request.db).count()
        let rules = try await Rule.query(on: request.db).sort(\.$order).all()
        let contactUser = try await self.getContactUser(appplicationSettings: appplicationSettings, on: request)
        
        return InstanceDto(uri: appplicationSettings?.baseAddress ?? "",
                           title: appplicationSettings?.webTitle ?? "",
                           description: appplicationSettings?.webDescription ?? "",
                           email: appplicationSettings?.webEmail ?? "",
                           version: Constants.version,
                           thumbnail: appplicationSettings?.webThumbnail ?? "",
                           languages: appplicationSettings?.webLanguages.split(separator: ",").map({ String($0) }) ?? [],
                           rules: rules.map({ SimpleRuleDto(id: $0.order, text: $0.text) }),
                           registrationOpened: appplicationSettings?.isRegistrationOpened ?? false,
                           registrationByApprovalOpened: appplicationSettings?.isRegistrationByApprovalOpened ?? false,
                           registrationByInvitationsOpened: appplicationSettings?.isRegistrationByInvitationsOpened ?? false,
                           configuration: ConfigurationDto(statuses: ConfigurationStatusesDto(maxCharacters: appplicationSettings?.maxCharacters ?? 500,
                                                                                              maxMediaAttachments: appplicationSettings?.maxMediaAttachments ?? 4,
                                                                                              charactersReservedPerUrl: 23),
                                                           attachments: ConfigurationAttachmentsDto(supportedMimeTypes: ["image/png", "image/jpeg"],
                                                                                                    imageSizeLimit: appplicationSettings?.imageSizeLimit ?? 10_485_760)),
                           stats: InstanceStatisticsDto(userCount: userCount,
                                                        statusCount: statusCount,
                                                        domainCount: 1),
                           contact: contactUser)
    }
    
    private func getContactUser(appplicationSettings: ApplicationSettings?, on request: Request) async throws -> UserDto? {
        guard let contactUserId = appplicationSettings?.webContactUserId.toId() else {
            return nil
        }
        
        guard let user = try await User.query(on: request.db).filter(\.$id == contactUserId).first() else {
            return nil
        }
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        var userDto = UserDto(from: user, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
        userDto.email = nil
        userDto.locale = nil
        
        return userDto
    }
}
