//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum ErrorItemSourceDto: String {
    case client
    case server
}

extension ErrorItemSourceDto {
    public func translate() -> ErrorItemSource {
        switch self {
        case .client:
            return ErrorItemSource.client
        case .server:
            return ErrorItemSource.server
        }
    }
    
    public static func from(_ errorItemSource: ErrorItemSource) -> ErrorItemSourceDto {
        switch errorItemSource {
        case .client:
            return ErrorItemSourceDto.client
        case .server:
            return ErrorItemSourceDto.server
        }
    }
}

extension ErrorItemSourceDto: Content { }
