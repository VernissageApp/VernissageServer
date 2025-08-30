//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

enum StatusActivityPubEventResultDto: String {
    /// New event waiting for processing.
    case waiting
    
    /// Event is processing by job.
    case processing
    
    /// Event has been successfully processed by job.
    /// There wasn't any errors during sending information to remote instances.
    case finished
    
    /// Event has been successfully processed by job.
    /// During processing some instances returned errors or didn't response at all.
    case finishedWithErrors
    
    /// Event has not been processed by job because of critical error.
    case failed
}

extension StatusActivityPubEventResultDto {
    public func translate() -> StatusActivityPubEventResult {
        switch self {
        case .waiting:
            return StatusActivityPubEventResult.waiting
        case .processing:
            return StatusActivityPubEventResult.processing
        case .finished:
            return StatusActivityPubEventResult.finished
        case .finishedWithErrors:
            return StatusActivityPubEventResult.finishedWithErrors
        case .failed:
            return StatusActivityPubEventResult.failed
        }
    }
    
    public static func from(_ statusActivityPubEventResult: StatusActivityPubEventResult) -> StatusActivityPubEventResultDto {
        switch statusActivityPubEventResult {
        case .waiting:
            return StatusActivityPubEventResultDto.waiting
        case .processing:
            return StatusActivityPubEventResultDto.processing
        case .finished:
            return StatusActivityPubEventResultDto.finished
        case .finishedWithErrors:
            return StatusActivityPubEventResultDto.finishedWithErrors
        case .failed:
            return StatusActivityPubEventResultDto.failed
        }
    }
}

extension StatusActivityPubEventResultDto: Content { }
