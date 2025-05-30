//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ReportDto {
    var id: String?
    var user: UserDto
    var reportedUser: UserDto
    var status: StatusDto?
    var mainStatusId: String?
    var comment: String?
    var forward: Bool
    var category: String?
    var ruleIds: [String]?
    var considerationDate: Date?
    var considerationUser: UserDto?
    var createdAt: Date?
    var updatedAt: Date?
}

extension ReportDto {
    init(from report: Report, status: StatusDto?, baseImagesPath: String, baseAddress: String) {
        let mainStatusId: String? = if let mainStatusId = report.$mainStatus.id { "\(mainStatusId)" } else { nil }
        
        self.init(id: report.stringId(),
                  user: UserDto(from: report.user, baseImagesPath: baseImagesPath, baseAddress: baseAddress),
                  reportedUser: UserDto(from: report.reportedUser, baseImagesPath: baseImagesPath, baseAddress: baseAddress),
                  status: status,
                  mainStatusId: mainStatusId,
                  comment: report.comment,
                  forward: report.forward,
                  category: report.category,
                  ruleIds: report.ruleIds?.split(separator: ",").map({ String($0) }),
                  considerationDate: report.considerationDate,
                  considerationUser: ReportDto.getUserDto(user: report.considerationUser, baseImagesPath: baseImagesPath, baseAddress: baseAddress),
                  createdAt: report.createdAt,
                  updatedAt: report.updatedAt)
    }
    
    private static func getUserDto(user: User?, baseImagesPath: String, baseAddress: String) -> UserDto? {
        guard let user else {
            return nil
        }
        
        return UserDto(from: user, baseImagesPath: baseImagesPath, baseAddress: baseAddress)
    }
}

extension ReportDto: Content { }
