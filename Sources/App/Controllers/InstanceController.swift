//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
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
        
        return InstanceDto(uri: appplicationSettings?.baseAddress ?? "",
                           title: "",
                           description: "",
                           email: "",
                           version: "",
                           thumbnail: "",
                           languages: ["en"],
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
                                                        domainCount: 1))
    }
}
