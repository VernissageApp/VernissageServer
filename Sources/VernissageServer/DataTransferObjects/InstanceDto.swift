//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct InstanceDto {
    var uri: String
    var title: String
    var description: String
    var longDescription: String
    var email: String
    var version: String
    var thumbnail: String
    var languages: [String]
    var rules: [SimpleRuleDto]
    
    var registrationOpened: Bool
    var registrationByApprovalOpened: Bool
    var registrationByInvitationsOpened: Bool
    
    var configuration: ConfigurationDto
    var stats: InstanceStatisticsDto
    var contact: UserDto?
}

extension InstanceDto: Content { }
