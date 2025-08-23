//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct BusinessCardsServiceKey: StorageKey {
        typealias Value = BusinessCardsServiceType
    }

    var businessCardsService: BusinessCardsServiceType {
        get {
            self.application.storage[BusinessCardsServiceKey.self] ?? BusinessCardsService()
        }
        nonmutating set {
            self.application.storage[BusinessCardsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol BusinessCardsServiceType: Sendable {
    /// Converts a `BusinessCard` entity to a `BusinessCardDto`.
    /// - Parameters:
    ///   - businessCard: The business card entity to convert.
    ///   - context: The execution context used for configuration and services.
    /// - Returns: A `BusinessCardDto` representing the business card.
    func convertToDto(businessCard: BusinessCard, on context: ExecutionContext) -> BusinessCardDto
    
    /// Converts a `SharedBusinessCard` entity to a `SharedBusinessCardDto`, optionally including messages.
    /// - Parameters:
    ///   - sharedBusinessCard: The shared business card entity to convert.
    ///   - messages: An optional array of shared business card messages to include.
    ///   - context: The execution context used for configuration and services.
    /// - Returns: A `SharedBusinessCardDto` representing the shared business card with messages.
    func convertToDto(sharedBusinessCard: SharedBusinessCard, messages: [SharedBusinessCardMessage]?, on context: ExecutionContext) -> SharedBusinessCardDto
    
    /// Converts a `SharedBusinessCard` entity and an associated `BusinessCard` entity to a `SharedBusinessCardDto`, optionally clearing sensitive information.
    /// - Parameters:
    ///   - sharedBusinessCard: The shared business card entity to convert.
    ///   - businessCard: The business card entity associated with the shared business card.
    ///   - clearSensitive: A flag indicating whether to clear sensitive fields such as title and note.
    ///   - context: The execution context used for configuration and services.
    /// - Returns: A `SharedBusinessCardDto` representing the combined shared business card data.
    func convertToDto(sharedBusinessCard: SharedBusinessCard, with businessCard: BusinessCard, clearSensitive: Bool, on context: ExecutionContext) -> SharedBusinessCardDto
}

/// A service for managing user's business card.
final class BusinessCardsService: BusinessCardsServiceType {
    func convertToDto(businessCard: BusinessCard, on context: ExecutionContext) -> BusinessCardDto {
        let baseImagesPath = context.services.storageService.getBaseImagesPath(on: context)
        let baseAddress = context.settings.cached?.baseAddress ?? ""
        
        return BusinessCardDto(from: businessCard, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
    }
    
    func convertToDto(sharedBusinessCard: SharedBusinessCard, messages: [SharedBusinessCardMessage]? = nil, on context: ExecutionContext) -> SharedBusinessCardDto {
        let baseImagesPath = context.services.storageService.getBaseImagesPath(on: context)
        let baseAddress = context.settings.cached?.baseAddress ?? ""
        
        return SharedBusinessCardDto(from: sharedBusinessCard, messages: messages, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
    }
    
    func convertToDto(sharedBusinessCard: SharedBusinessCard, with businessCard: BusinessCard, clearSensitive: Bool, on context: ExecutionContext) -> SharedBusinessCardDto {
        let baseImagesPath = context.services.storageService.getBaseImagesPath(on: context)
        let baseAddress = context.settings.cached?.baseAddress ?? ""
        
        let businessCardDto = BusinessCardDto(from: businessCard, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        var sharedBusinessCardDto = SharedBusinessCardDto(from: sharedBusinessCard,
                                                          messages: sharedBusinessCard.messages,
                                                          businessCardDto: businessCardDto,
                                                          baseAddress: baseAddress,
                                                          baseImagesPath: baseImagesPath)
        
        if clearSensitive {
            sharedBusinessCardDto.title = ""
            sharedBusinessCardDto.note = ""
        }
        
        return sharedBusinessCardDto
    }
}
