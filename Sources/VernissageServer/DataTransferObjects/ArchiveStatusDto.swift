//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum ArchiveStatusDto: String {
    /// New archive requested.
    case `new`
    
    /// System is creating new zip file with archive.
    case processing
    
    /// Archive has been created successfully.
    case ready
    
    /// Archive is old and not available now.
    case expired
    
    /// Archive has not been created.
    case error
}

extension ArchiveStatusDto {
    public func translate() -> ArchiveStatus {
        switch self {
        case .new:
            return ArchiveStatus.new
        case .processing:
            return ArchiveStatus.processing
        case .ready:
            return ArchiveStatus.ready
        case .expired:
            return ArchiveStatus.expired
        case .error:
            return ArchiveStatus.error
        }
    }
    
    public static func from(_ archiveStatus: ArchiveStatus) -> ArchiveStatusDto {
        switch archiveStatus {
        case .new:
            return ArchiveStatusDto.new
        case .processing:
            return ArchiveStatusDto.processing
        case .ready:
            return ArchiveStatusDto.ready
        case .expired:
            return ArchiveStatusDto.expired
        case .error:
            return ArchiveStatusDto.error
        }
    }
}

extension ArchiveStatusDto: Content { }
