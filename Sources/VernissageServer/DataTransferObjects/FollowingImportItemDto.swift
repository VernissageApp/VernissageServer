//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct FollowingImportItemDto {
    var id: String?
    var account: String
    var showBoosts: Bool
    var languages: String?
    var status: FollowingImportItemStatusDto
    var errorMessage: String?
    var startedAt: Date?
    var endedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
}

extension FollowingImportItemDto {
    init(from followingImportItem: FollowingImportItem) {
        self.init(id: followingImportItem.stringId(),
                  account: followingImportItem.account,
                  showBoosts: followingImportItem.showBoosts,
                  languages: followingImportItem.languages,
                  status: FollowingImportItemStatusDto.from(followingImportItem.status),
                  errorMessage: followingImportItem.errorMessage,
                  startedAt: followingImportItem.startedAt,
                  endedAt: followingImportItem.endedAt,
                  createdAt: followingImportItem.createdAt,
                  updatedAt: followingImportItem.updatedAt)
    }
}

extension FollowingImportItemDto: Content { }
