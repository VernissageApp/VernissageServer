//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct ArticlesServiceKey: StorageKey {
        typealias Value = ArticlesServiceType
    }

    var articlesService: ArticlesServiceType {
        get {
            self.application.storage[ArticlesServiceKey.self] ?? ArticlesService()
        }
        nonmutating set {
            self.application.storage[ArticlesServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ArticlesServiceType: Sendable {
    func convertToDto(article: Article, on context: ExecutionContext) -> ArticleDto
}

/// A service for managing user mutes.
final class ArticlesService: ArticlesServiceType {
    func convertToDto(article: Article, on context: ExecutionContext) -> ArticleDto {
        let baseImagesPath = context.services.storageService.getBaseImagesPath(on: context)
        let baseAddress = context.settings.cached?.baseAddress ?? ""
        
        let bodyHtml = article.body.convertMarkdownToHtml()
        return ArticleDto(from: article, bodyHtml: bodyHtml, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
    }
}
