//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum FollowingImportItemStatusDto: String {
    case notProcessed
    case followed
    case sent
    case error
}

extension FollowingImportItemStatusDto {
    public func translate() -> FollowingImportItemStatus {
        switch self {
        case .notProcessed:
            return FollowingImportItemStatus.notProcessed
        case .followed:
            return FollowingImportItemStatus.followed
        case .sent:
            return FollowingImportItemStatus.sent
        case .error:
            return FollowingImportItemStatus.error
        }
    }
    
    public static func from(_ followingImportItemStatus: FollowingImportItemStatus) -> FollowingImportItemStatusDto {
        switch followingImportItemStatus {
        case .notProcessed:
            return FollowingImportItemStatusDto.notProcessed
        case .followed:
            return FollowingImportItemStatusDto.followed
        case .sent:
            return FollowingImportItemStatusDto.sent
        case .error:
            return FollowingImportItemStatusDto.error
        }
    }
}

extension FollowingImportItemStatusDto: Content { }
