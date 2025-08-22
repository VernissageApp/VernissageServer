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
    /// Converts an `Article` entity into an `ArticleDto`.
    /// - Parameters:
    ///   - article: The article entity to convert.
    ///   - context: The execution context for resolving paths and settings.
    /// - Returns: An `ArticleDto` representation of the article.
    func convertToDto(article: Article, on context: ExecutionContext) -> ArticleDto
    
    /// Determines if the given request is authorized to access the specified article.
    /// - Parameters:
    ///   - article: The article entity to check authorization for.
    ///   - request: The request containing user and application context.
    /// - Returns: A Boolean value indicating whether the request is authorized to access the article.
    func isAuthorized(article: Article, on request: Request) -> Bool
    
    /// Provides a list of allowed article visibility types based on the current request context.
    /// - Parameters:
    ///   - request: The request containing user and application context.
    /// - Returns: An array of `ArticleVisibilityDto` representing allowed visibilities for the request.
    func allowedVisibilities(on request: Request) -> [ArticleVisibilityDto]
}

/// A service for managing articles in the system.
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

        // When article is visble for signout on home always is accessible.
        if article.articleVisibilities.contains(where: { $0.articleVisibilityType == .signOutHome }) {
            return true
        }
        
        // When article is visible for signin on home all signed in users can access it.
        if request.userId != nil && article.articleVisibilities.contains(where: { $0.articleVisibilityType == .signInHome }) {
            return true
        }
        
        let applicationSettings = request.application.settings.cached
        
        // When article is visible on signout news and anonymous news are enabled.
        if article.articleVisibilities.contains(where: { $0.articleVisibilityType == .signOutNews }) && applicationSettings?.showNewsForAnonymous == true {
            return true
        }

        // When article is visible on signin news and news are enabled.
        if article.articleVisibilities.contains(where: { $0.articleVisibilityType == .signInNews }) && applicationSettings?.showNews == true {
            return true
        }

        return false
    }
    
    func allowedVisibilities(on request: Request) -> [ArticleVisibilityDto] {
        // Moderator and administrator have always permission to article.
        if request.isAdministrator || request.isModerator {
            return [.signInHome, .signInNews, .signOutHome, .signOutNews]
        }
        
        let applicationSettings = request.application.settings.cached
        var visibilities: [ArticleVisibilityDto] = [.signOutHome]

        if applicationSettings?.showNewsForAnonymous == true {
            visibilities.append(.signOutNews)
        }
        
        if request.userId != nil {
            visibilities.append(.signInHome)
            
            if applicationSettings?.showNews == true {
                visibilities.append(.signInNews)
            }
        }
        
        return visibilities
    }
}
