//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

final class InstanceController: RouteCollection {
    
    public static let uri: PathComponent = .constant("instance")
    
    func boot(routes: RoutesBuilder) throws {
        let instanceGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(InstanceController.uri)
        
        instanceGroup
            .grouped(EventHandlerMiddleware(.instance))
            .get(use: instance)
    }
    
    func instance(request: Request) async throws -> InstanceDto {
        let appplicationSettings = request.application.settings.cached
        
        let userCount = try await User.query(on: request.db).count()
        let statusCount = try await Status.query(on: request.db).count()
        let contactUser = try await self.getContactUser(appplicationSettings: appplicationSettings, on: request)
        
        return InstanceDto(uri: appplicationSettings?.baseAddress ?? "",
                           title: appplicationSettings?.webTitle ?? "",
                           description: appplicationSettings?.webDescription ?? "",
                           email: appplicationSettings?.webEmail ?? "",
                           version: "1.0.0-beta1",
                           thumbnail: appplicationSettings?.webThumbnail ?? "",
                           languages: appplicationSettings?.webLanguages.split(separator: ",").map({ String($0) }) ?? [],
                           rules: ["Rule 1", "Rule 2"],
                           registrationOpened: appplicationSettings?.isRegistrationOpened ?? false,
                           registrationByApprovalOpened: appplicationSettings?.isRegistrationByApprovalOpened ?? false,
                           registrationByInvitationsOpened: appplicationSettings?.isRegistrationByInvitationsOpened ?? false,
                           configuration: ConfigurationDto(statuses: ConfigurationStatusesDto(maxCharacters: 500,
                                                                                              maxMediaAttachments: 4,
                                                                                              charactersReservedPerUrl: 23),
                                                           attachments: ConfigurationAttachmentsDto(supportedMimeTypes: ["image/png", "image/jpeg"],
                                                                                                    imageSizeLimit: 6_291_456)),
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
        var userDto = UserDto(from: user, flexiFields: [], baseStoragePath: baseStoragePath)
        userDto.email = nil
        userDto.locale = nil
        
        return userDto
    }
}
