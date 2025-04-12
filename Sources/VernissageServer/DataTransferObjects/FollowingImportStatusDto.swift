//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum FollowingImportStatusDto: String {
    case new
    case processing
    case finished
}

extension FollowingImportStatusDto {
    public func translate() -> FollowingImportStatus {
        switch self {
        case .new:
            return FollowingImportStatus.new
        case .processing:
            return FollowingImportStatus.processing
        case .finished:
            return FollowingImportStatus.finished
        }
    }
    
    public static func from(_ followingImportStatus: FollowingImportStatus) -> FollowingImportStatusDto {
        switch followingImportStatus {
        case .new:
            return FollowingImportStatusDto.new
        case .processing:
            return FollowingImportStatusDto.processing
        case .finished:
            return FollowingImportStatusDto.finished
        }
    }
}

extension FollowingImportStatusDto: Content { }
