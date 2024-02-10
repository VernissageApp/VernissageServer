//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

public struct ReportDto {
    var id: String?
    var user: UserDto
    var reportedUser: UserDto
    var status: StatusDto?
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
    init(from report: Report, status: StatusDto?, baseStoragePath: String, baseAddress: String) {
        self.init(id: report.stringId(),
                  user: UserDto(from: report.user, baseStoragePath: baseStoragePath, baseAddress: baseAddress),
                  reportedUser: UserDto(from: report.reportedUser, baseStoragePath: baseStoragePath, baseAddress: baseAddress),
                  status: status,
                  comment: report.comment,
                  forward: report.forward,
                  category: report.category,
                  ruleIds: report.ruleIds?.split(separator: ",").map({ String($0) }),
                  considerationDate: report.considerationDate,
                  considerationUser: ReportDto.getUserDto(user: report.considerationUser, baseStoragePath: baseStoragePath, baseAddress: baseAddress),
                  createdAt: report.createdAt,
                  updatedAt: report.updatedAt)
    }
    
    private static func getUserDto(user: User?, baseStoragePath: String, baseAddress: String) -> UserDto? {
        guard let user else {
            return nil
        }
        
        return UserDto(from: user, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
    }
}

extension ReportDto: Content { }
