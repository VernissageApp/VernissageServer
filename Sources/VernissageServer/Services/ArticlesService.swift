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
    func isAuthorized(article: Article, on request: Request) -> Bool
    func allowedVisibilities(on request: Request) -> [ArticleVisibilityDto]
}

/// A service for managing user mutes.
final class ArticlesService: ArticlesServiceType {
    func convertToDto(article: Article, on context: ExecutionContext) -> ArticleDto {
        let baseImagesPath = context.services.storageService.getBaseImagesPath(on: context)
        let baseAddress = context.settings.cached?.baseAddress ?? ""
        
        let bodyHtml = article.body.convertMarkdownToHtml()
        return ArticleDto(from: article, bodyHtml: bodyHtml, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
    }
    
    func isAuthorized(article: Article, on request: Request) -> Bool {
        // Moderator and administrator have always permission to article.
        if request.isAdministrator || request.isModerator {
            return true
        }

        // When article is visble for signout on home always is accesible.
        if article.articleVisibilities.contains(where: { $0.articleVisibilityType == .signOutHome }) {
            return true
        }
        
        // Wen article is visible for signin on home all signed in users can access it.
        if request.userId != nil && article.articleVisibilities.contains(where: { $0.articleVisibilityType == .signInHome }) {
            return true
        }
        
        let appplicationSettings = request.application.settings.cached
        
        // Wnen article is visibe on signout news and anonymous news are enabled.
        if article.articleVisibilities.contains(where: { $0.articleVisibilityType == .signOutNews }) && appplicationSettings?.showNewsForAnonymous == true {
            return true
        }

        // When article is visible on signin news and news are enabled.
        if article.articleVisibilities.contains(where: { $0.articleVisibilityType == .signInNews }) && appplicationSettings?.showNews == true {
            return true
        }

        return false
    }
    
    func allowedVisibilities(on request: Request) -> [ArticleVisibilityDto] {
        // Moderator and administrator have always permission to article.
        if request.isAdministrator || request.isModerator {
            return [.signInHome, .signInNews, .signOutHome, .signOutNews]
        }
        
        let appplicationSettings = request.application.settings.cached
        var visibilities: [ArticleVisibilityDto] = [.signOutHome]

        if appplicationSettings?.showNewsForAnonymous == true {
            visibilities.append(.signOutNews)
        }
        
        if request.userId != nil {
            visibilities.append(.signInHome)
            
            if appplicationSettings?.showNews == true {
                visibilities.append(.signInNews)
            }
        }
        
        return visibilities
    }
}
