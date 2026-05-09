//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum StatusActivityPubEventTypeDto: String {
    case create
    case update
    case like
    case unlike
    case announce
    case unannounce
    case pin
    case unpin
}

extension StatusActivityPubEventTypeDto {
    public func translate() -> StatusActivityPubEventType {
        switch self {
        case .create:
            return StatusActivityPubEventType.create
        case .update:
            return StatusActivityPubEventType.update
        case .like:
            return StatusActivityPubEventType.like
        case .unlike:
            return StatusActivityPubEventType.unlike
        case .announce:
            return StatusActivityPubEventType.announce
        case .unannounce:
            return StatusActivityPubEventType.unannounce
        case .pin:
            return StatusActivityPubEventType.pin
        case .unpin:
            return StatusActivityPubEventType.unpin
        }
    }
    
    public static func from(_ statusActivityPubEventType: StatusActivityPubEventType) -> StatusActivityPubEventTypeDto {
        switch statusActivityPubEventType {
        case .create:
            return StatusActivityPubEventTypeDto.create
        case .update:
            return StatusActivityPubEventTypeDto.update
        case .like:
            return StatusActivityPubEventTypeDto.like
        case .unlike:
            return StatusActivityPubEventTypeDto.unlike
        case .announce:
            return StatusActivityPubEventTypeDto.announce
        case .unannounce:
            return StatusActivityPubEventTypeDto.unannounce
        case .pin:
            return StatusActivityPubEventTypeDto.pin
        case .unpin:
            return StatusActivityPubEventTypeDto.unpin
        }
    }
}

extension StatusActivityPubEventTypeDto: Content { }
