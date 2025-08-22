//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Vapor
import Fluent
import ActivityPubKit

extension AtomController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let atomGroup = routes
            .grouped("atom")
        
        // Support user's profile for Atom feed: https://example.com/atom/users/@johndoe
        atomGroup
            .grouped(EventHandlerMiddleware(.atomUser))
            .grouped(CacheControlMiddleware(.noStore))
            .get("users", ":name", use: user)
        
        // Support for local timeline Atom feed: https://example.com/atom/local
        atomGroup
            .grouped(EventHandlerMiddleware(.atomLocal))
            .grouped(CacheControlMiddleware(.noStore))
            .get("local", use: local)
        
        // Support for local timeline Atom feed: https://example.com/atom/global
        atomGroup
            .grouped(EventHandlerMiddleware(.atomGlobal))
            .grouped(CacheControlMiddleware(.noStore))
            .get("global", use: global)
        
        // Support for local timeline Atom feed: https://example.com/atom/trending/daily
        atomGroup
            .grouped(EventHandlerMiddleware(.atomTrending))
            .grouped(CacheControlMiddleware(.noStore))
            .get("trending", ":period", use: trending)
        
        // Support for local timeline Atom feed: https://example.com/atom/featured
        atomGroup
            .grouped(EventHandlerMiddleware(.atomFeatured))
            .grouped(CacheControlMiddleware(.noStore))
            .get("featured", use: featured)
        
        // Support for local timeline Atom feed: https://example.com/atom/categories/Abstract
        atomGroup
            .grouped(EventHandlerMiddleware(.atomCategories))
            .grouped(CacheControlMiddleware(.noStore))
            .get("categories", ":category", use: categories)
        
        // Support for local timeline Atom feed: https://example.com/atom/hashtags/photography
        atomGroup
            .grouped(EventHandlerMiddleware(.atomHashtags))
            .grouped(CacheControlMiddleware(.noStore))
            .get("hashtags", ":hashtag", use: hashtags)
    }
}

/// Controller for exposing Atom feeds.
///
/// This controller hosts endpoints for different Atom feeds.
///
/// > Important: Base controller URL: `/atom`.
struct AtomController {
    let activityPubActorsController = ActivityPubActorsController()
        
    /// Returns user's Atom feed with latest statuses.
    ///
    /// > Important: Endpoint URL: `/atom/users/:name`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/atom/users/@johndoe" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="utf-8"?>
    /// <feed xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">
    ///    <title>John Doe</title>
    ///    <subtitle>Public posts from @johndoe@example.com</subtitle>
    ///    <link>http://example.com/@johndoe</link>
    ///    <generator version="1.3.0">Vernissage</generator>
    ///    <updated>2025-02-14T12:44:01.200Z</updated>
    ///    <author>
    ///        <name>John Doe</name>
    ///        <uri>http://example.com/@johndoe</uri>
    ///    </author>
    ///    <icon>https://example.com/0fc159c5d78d496f9bdb3195b8e651cc.png</icon>
    ///    <logo>https://example.com/0fc159c5d78d496f9bdb3195b8e651cc.png</logo>
    ///    <entry>
    ///        <id>http://example.com/@johndoe/7471254701275615610</id>
    ///        <title>John Doe photo</title>
    ///        <link>http://exmple.com/@johndoe/7471254701275615610</link>
    ///        <updated>2025-02-14T12:44:01.200Z</updated>
    ///        <published>2025-02-14T12:44:01.200Z</published>
    ///        <author>
    ///            <name>John Doe</name>
    ///            <uri>http://example.com/@johndoe</uri>
    ///        </author>
    ///        <content type="html">&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</content>
    ///        <media:content url="https://example.com/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///            <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///            <media:rating scheme="urn:simple">adult</media:rating>
    ///        </media:content>
    ///    </entry>
    /// </feed>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: User's statuses Atom feed.
    @Sendable
    func user(request: Request) async throws -> Response {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }

        let usersService = request.application.services.usersService
        let atomService = request.application.services.atomService
        let clearedUserName = userName.deletingPrefix("@")
        let userFromDb = try await usersService.get(userName: clearedUserName, on: request.db)
        
        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        let xmlDocument = try await atomService.feed(for: user, on: request.executionContext)
        return try await createAtomResponse(xmlDocument, request)
    }
    
    /// Returns Atom feed with local statuses.
    ///
    /// > Important: Endpoint URL: `/atom/local`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/atom/local" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="utf-8"?>
    /// <feed xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">
    ///    <title>Local timeline</title>
    ///    <subtitle>Public posts from the instance</subtitle>
    ///    <link>http://example.com/@johndoe</link>
    ///    <generator version="1.3.0">Vernissage</generator>
    ///    <updated>2025-02-14T12:44:01.200Z</updated>
    ///    <entry>
    ///        <id>http://example.com/@johndoe/7471254701275615610</id>
    ///        <title>John Doe photo</title>
    ///        <link>http://exmple.com/@johndoe/7471254701275615610</link>
    ///        <updated>2025-02-14T12:44:01.200Z</updated>
    ///        <published>2025-02-14T12:44:01.200Z</published>
    ///        <author>
    ///            <name>John Doe</name>
    ///            <uri>http://example.com/@johndoe</uri>
    ///        </author>
    ///        <content type="html">&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</content>
    ///        <media:content url="https://example.com/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///            <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///            <media:rating scheme="urn:simple">adult</media:rating>
    ///        </media:content>
    ///    </entry>
    /// </feed>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Atom feed with local statuses.
    @Sendable
    func local(request: Request) async throws -> Response {
        let applicationSettings = request.application.settings.cached
        if applicationSettings?.showLocalTimelineForAnonymous == false {
            throw ActionsForbiddenError.localTimelineForbidden
        }
        
        let atomService = request.application.services.atomService
        let xmlDocument = try await atomService.local(on: request.executionContext)
        return try await createAtomResponse(xmlDocument, request)
    }
    
    /// Returns Atom feed with all statuses.
    ///
    /// > Important: Endpoint URL: `/atom/global`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/atom/global" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="utf-8"?>
    /// <feed xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">
    ///    <title>Global timeline</title>
    ///    <subtitle>All public posts</subtitle>
    ///    <link>http://example.com/@johndoe</link>
    ///    <generator version="1.3.0">Vernissage</generator>
    ///    <updated>2025-02-14T12:44:01.200Z</updated>
    ///    <entry>
    ///        <id>http://example.com/@johndoe/7471254701275615610</id>
    ///        <title>John Doe photo</title>
    ///        <link>http://exmple.com/@johndoe/7471254701275615610</link>
    ///        <updated>2025-02-14T12:44:01.200Z</updated>
    ///        <published>2025-02-14T12:44:01.200Z</published>
    ///        <author>
    ///            <name>John Doe</name>
    ///            <uri>http://example.com/@johndoe</uri>
    ///        </author>
    ///        <content type="html">&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</content>
    ///        <media:content url="https://example.com/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///            <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///            <media:rating scheme="urn:simple">adult</media:rating>
    ///        </media:content>
    ///    </entry>
    /// </feed>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Atom feed with globla statuses.
    @Sendable
    func global(request: Request) async throws -> Response {
        let applicationSettings = request.application.settings.cached
        if applicationSettings?.showLocalTimelineForAnonymous == false {
            throw ActionsForbiddenError.localTimelineForbidden
        }
        
        let atomService = request.application.services.atomService
        let xmlDocument = try await atomService.global(on: request.executionContext)
        return try await createAtomResponse(xmlDocument, request)
    }
    
    /// Returns Atom feed with trending statuses.
    ///
    /// > Important: Endpoint URL: `/atom/trending/:period`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/atom/trending/daily" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="utf-8"?>
    /// <feed xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">
    ///    <title>Trending posts (daily)</title>
    ///    <subtitle>Trending posts on the instance</subtitle>
    ///    <link>http://example.com/@johndoe</link>
    ///    <generator version="1.3.0">Vernissage</generator>
    ///    <updated>2025-02-14T12:44:01.200Z</updated>
    ///    <entry>
    ///        <id>http://example.com/@johndoe/7471254701275615610</id>
    ///        <title>John Doe photo</title>
    ///        <link>http://exmple.com/@johndoe/7471254701275615610</link>
    ///        <updated>2025-02-14T12:44:01.200Z</updated>
    ///        <published>2025-02-14T12:44:01.200Z</published>
    ///        <author>
    ///            <name>John Doe</name>
    ///            <uri>http://example.com/@johndoe</uri>
    ///        </author>
    ///        <content type="html">&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</content>
    ///        <media:content url="https://example.com/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///            <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///            <media:rating scheme="urn:simple">adult</media:rating>
    ///        </media:content>
    ///    </entry>
    /// </feed>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Atom feed with globla statuses.
    @Sendable
    func trending(request: Request) async throws -> Response {
        let applicationSettings = request.application.settings.cached
        if applicationSettings?.showTrendingForAnonymous == false {
            throw ActionsForbiddenError.trendingForbidden
        }
        
        let periodString = request.parameters.get("period") ?? "daily"
        let period = TrendingStatusPeriodDto(rawValue: periodString) ?? .daily
        
        let atomService = request.application.services.atomService
        let xmlDocument = try await atomService.trending(period: period.translate(), on: request.executionContext)
        return try await createAtomResponse(xmlDocument, request)
    }
    
    /// Returns Atom feed with featured statuses.
    ///
    /// > Important: Endpoint URL: `/atom/featured`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/atom/featured" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="utf-8"?>
    /// <feed xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">
    ///    <title>Editor's choice timeline</title>
    ///    <subtitle>All featured public posts</subtitle>
    ///    <link>http://example.com/@johndoe</link>
    ///    <generator version="1.3.0">Vernissage</generator>
    ///    <updated>2025-02-14T12:44:01.200Z</updated>
    ///    <entry>
    ///        <id>http://example.com/@johndoe/7471254701275615610</id>
    ///        <title>John Doe photo</title>
    ///        <link>http://exmple.com/@johndoe/7471254701275615610</link>
    ///        <updated>2025-02-14T12:44:01.200Z</updated>
    ///        <published>2025-02-14T12:44:01.200Z</published>
    ///        <author>
    ///            <name>John Doe</name>
    ///            <uri>http://example.com/@johndoe</uri>
    ///        </author>
    ///        <content type="html">&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</content>
    ///        <media:content url="https://example.com/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///            <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///            <media:rating scheme="urn:simple">adult</media:rating>
    ///        </media:content>
    ///    </entry>
    /// </feed>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Atom feed with featured statuses.
    @Sendable
    func featured(request: Request) async throws -> Response {
        let applicationSettings = request.application.settings.cached
        if applicationSettings?.showEditorsChoiceForAnonymous == false {
            throw ActionsForbiddenError.editorsStatusesChoiceForbidden
        }
        
        let atomService = request.application.services.atomService
        let xmlDocument = try await atomService.featured(on: request.executionContext)
        return try await createAtomResponse(xmlDocument, request)
    }
    
    /// Returns Atom feed with categories statuses.
    ///
    /// > Important: Endpoint URL: `/atom/categories/:category`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/atom/categories/Abstract" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="utf-8"?>
    /// <feed xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">
    ///    <title>Animals</title>
    ///    <subtitle>Public post for category Animals</subtitle>
    ///    <link>http://example.com/@johndoe</link>
    ///    <generator version="1.3.0">Vernissage</generator>
    ///    <updated>2025-02-14T12:44:01.200Z</updated>
    ///    <entry>
    ///        <id>http://example.com/@johndoe/7471254701275615610</id>
    ///        <title>John Doe photo</title>
    ///        <link>http://exmple.com/@johndoe/7471254701275615610</link>
    ///        <updated>2025-02-14T12:44:01.200Z</updated>
    ///        <published>2025-02-14T12:44:01.200Z</published>
    ///        <author>
    ///            <name>John Doe</name>
    ///            <uri>http://example.com/@johndoe</uri>
    ///        </author>
    ///        <content type="html">&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</content>
    ///        <media:content url="https://example.com/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///            <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///            <media:rating scheme="urn:simple">adult</media:rating>
    ///        </media:content>
    ///    </entry>
    /// </feed>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Atom feed with featured statuses.
    @Sendable
    func categories(request: Request) async throws -> Response {
        let applicationSettings = request.application.settings.cached
        if applicationSettings?.showCategoriesForAnonymous == false {
            throw ActionsForbiddenError.categoriesForbidden
        }
        
        guard let categoryName = request.parameters.get("category") else {
            throw Abort(.badRequest)
        }
        
        guard let category = try await Category.query(on: request.db)
            .filter(\.$nameNormalized == categoryName.uppercased())
            .first() else {
            throw Abort(.notFound)
        }
        
        let atomService = request.application.services.atomService
        let xmlDocument = try await atomService.categories(category: category, on: request.executionContext)
        return try await createAtomResponse(xmlDocument, request)
    }
    
    /// Returns Atom feed with statuses with hashtag.
    ///
    /// > Important: Endpoint URL: `/atom/hashtags/:hashtag`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/atom/hashtags/photography" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="utf-8"?>
    /// <feed xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">
    ///    <title>#street</title>
    ///    <subtitle>Public post for tag #street</subtitle>
    ///    <link>http://example.com/@johndoe</link>
    ///    <generator version="1.3.0">Vernissage</generator>
    ///    <updated>2025-02-14T12:44:01.200Z</updated>
    ///    <entry>
    ///        <id>http://example.com/@johndoe/7471254701275615610</id>
    ///        <title>John Doe photo</title>
    ///        <link>http://exmple.com/@johndoe/7471254701275615610</link>
    ///        <updated>2025-02-14T12:44:01.200Z</updated>
    ///        <published>2025-02-14T12:44:01.200Z</published>
    ///        <author>
    ///            <name>John Doe</name>
    ///            <uri>http://example.com/@johndoe</uri>
    ///        </author>
    ///        <content type="html">&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</content>
    ///        <media:content url="https://example.com/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///            <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///            <media:rating scheme="urn:simple">adult</media:rating>
    ///        </media:content>
    ///    </entry>
    /// </feed>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Atom feed with statuses with hashtag.
    @Sendable
    func hashtags(request: Request) async throws -> Response {
        let applicationSettings = request.application.settings.cached
        if applicationSettings?.showHashtagsForAnonymous == false {
            throw ActionsForbiddenError.hashtagsForbidden
        }
        
        guard let hashtag = request.parameters.get("hashtag") else {
            throw Abort(.badRequest)
        }
                
        let atomService = request.application.services.atomService
        let xmlDocument = try await atomService.hashtags(hashtag: hashtag, on: request.executionContext)
        return try await createAtomResponse(xmlDocument, request)
    }
    
    private func createAtomResponse(_ xmlDocument: String, _ request: Request) async throws -> Response {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentType, value: "application/atom+xml; charset=utf-8")
        
        return try await xmlDocument.encodeResponse(status: .ok, headers: headers, for: request)
    }
}
