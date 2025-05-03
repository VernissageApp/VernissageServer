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
    func convertToDto(businessCard: BusinessCard, on context: ExecutionContext) -> BusinessCardDto
    func convertToDto(sharedBusinessCard: SharedBusinessCard, messages: [SharedBusinessCardMessage]?, on context: ExecutionContext) -> SharedBusinessCardDto
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
