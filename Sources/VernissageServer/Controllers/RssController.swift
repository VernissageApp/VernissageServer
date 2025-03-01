//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Vapor
import Fluent
import ActivityPubKit

extension RssController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let rssGroup = routes
            .grouped("rss")
        
        // Support user's profile for RSS feed: https://example.com/rss/users/@johndoe
        rssGroup
            .grouped(EventHandlerMiddleware(.rssUser))
            .grouped(CacheControlMiddleware(.noStore))
            .get("users", ":name", use: user)
        
        // Support for local timeline RSS feed: https://example.com/rss/local
        rssGroup
            .grouped(EventHandlerMiddleware(.rssLocal))
            .grouped(CacheControlMiddleware(.noStore))
            .get("local", use: local)
        
        // Support for local timeline RSS feed: https://example.com/rss/global
        rssGroup
            .grouped(EventHandlerMiddleware(.rssGlobal))
            .grouped(CacheControlMiddleware(.noStore))
            .get("global", use: global)
        
        // Support for local timeline RSS feed: https://example.com/rss/trending/daily
        rssGroup
            .grouped(EventHandlerMiddleware(.rssTrending))
            .grouped(CacheControlMiddleware(.noStore))
            .get("trending", ":period", use: trending)
        
        // Support for local timeline RSS feed: https://example.com/rss/featured
        rssGroup
            .grouped(EventHandlerMiddleware(.rssFeatured))
            .grouped(CacheControlMiddleware(.noStore))
            .get("featured", use: featured)
        
        // Support for local timeline RSS feed: https://example.com/rss/categories/Abstract
        rssGroup
            .grouped(EventHandlerMiddleware(.rssCategories))
            .grouped(CacheControlMiddleware(.noStore))
            .get("categories", ":category", use: categories)
        
        // Support for local timeline RSS feed: https://example.com/rss/hashtags/photography
        rssGroup
            .grouped(EventHandlerMiddleware(.rssHashtags))
            .grouped(CacheControlMiddleware(.noStore))
            .get("hashtags", ":hashtag", use: hashtags)
    }
}

/// Controller for exposing RSS feeds.
///
/// This controller hosts endpoints for different RSS feeds.
///
/// > Important: Base controller URL: `/rss`.
struct RssController {
    let activityPubActorsController = ActivityPubActorsController()
        
    /// Returns user's RSS feed with latest statuses.
    ///
    /// > Important: Endpoint URL: `/rss/users/:name`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/rss/users/@johndoe" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <rss xmlns:webfeeds="http://webfeeds.org/rss/1.0" xmlns:media="http://search.yahoo.com/mrss/" version="2.0">
    ///    <channel>
    ///        <title>John Doe</title>
    ///        <description>Public posts from @johndoe@example.com</description>
    ///        <link>http://example.com/@johndoe</link>
    ///        <generator>Vernissage 1.0.0-buildx</generator>
    ///        <webfeeds:icon>https://example.com/assets/icons/icon-512x512.png</webfeeds:icon>
    ///        <lastBuildDate>Fri, 14 Feb 2025 12:44:01 +0000</lastBuildDate>
    ///        <image>
    ///            <url>https://example.com/vernissage-test/0fc159c5d78d496f9bdb3195b8e651cc.png</url>
    ///            <title>John Doe</title>
    ///            <link>http://example.com/@johndoe</link>
    ///        </image>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7471254701275615610</guid>
    ///            <pubDate>Fri, 14 Feb 2025 12:44:01 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7471254701275615610</link>
    ///            <description>&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///                <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///                <media:rating scheme="urn:simple">adult</media:rating>
    ///            </media:content>
    ///        </item>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7470218914077610911</guid>
    ///            <pubDate>Tue, 11 Feb 2025 17:44:38 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7470218914077610911</link>
    ///            <description>&lt;p&gt;AAAAAA&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/a72ae8cdc2fa4461abaacc24af903f03.jpg" medium="image" type="image/jpeg">
    ///                <media:description type="plain"></media:description>
    ///                <media:rating scheme="urn:simple">nonadult</media:rating>
    ///            </media:content>
    ///        </item>
    ///    </channel>
    /// </rss>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: User's statuses RSS feed.
    @Sendable
    func user(request: Request) async throws -> Response {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }

        let usersService = request.application.services.usersService
        let rssService = request.application.services.rssService
        let clearedUserName = userName.deletingPrefix("@")
        let userFromDb = try await usersService.get(userName: clearedUserName, on: request.db)
        
        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        let xmlDocument = try await rssService.feed(for: user, on: request.executionContext)
        return try await createRssResponse(xmlDocument, request)
    }
    
    /// Returns RSS feed with local statuses.
    ///
    /// > Important: Endpoint URL: `/rss/local`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/rss/local" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <rss xmlns:webfeeds="http://webfeeds.org/rss/1.0" xmlns:media="http://search.yahoo.com/mrss/" version="2.0">
    ///    <channel>
    ///        <title>Local timeline</title>
    ///        <description>Public posts from the instance https://example.com</description>
    ///        <link>http://example.com/home?t=local</link>
    ///        <generator>Vernissage 1.0.0-buildx</generator>
    ///        <lastBuildDate>Fri, 14 Feb 2025 12:44:01 +0000</lastBuildDate>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7471254701275615610</guid>
    ///            <pubDate>Fri, 14 Feb 2025 12:44:01 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7471254701275615610</link>
    ///            <description>&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///                <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///                <media:rating scheme="urn:simple">adult</media:rating>
    ///            </media:content>
    ///        </item>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7470218914077610911</guid>
    ///            <pubDate>Tue, 11 Feb 2025 17:44:38 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7470218914077610911</link>
    ///            <description>&lt;p&gt;AAAAAA&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/a72ae8cdc2fa4461abaacc24af903f03.jpg" medium="image" type="image/jpeg">
    ///                <media:description type="plain"></media:description>
    ///                <media:rating scheme="urn:simple">nonadult</media:rating>
    ///            </media:content>
    ///        </item>
    ///    </channel>
    /// </rss>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: RSS feed with local statuses.
    @Sendable
    func local(request: Request) async throws -> Response {
        let appplicationSettings = request.application.settings.cached
        if appplicationSettings?.showLocalTimelineForAnonymous == false {
            throw ActionsForbiddenError.localTimelineForbidden
        }
        
        let rssService = request.application.services.rssService
        let xmlDocument = try await rssService.local(on: request.executionContext)
        return try await createRssResponse(xmlDocument, request)
    }
    
    /// Returns RSS feed with all statuses.
    ///
    /// > Important: Endpoint URL: `/rss/global`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/rss/global" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <rss xmlns:webfeeds="http://webfeeds.org/rss/1.0" xmlns:media="http://search.yahoo.com/mrss/" version="2.0">
    ///    <channel>
    ///        <title>Global timeline</title>
    ///        <description>All public posts/description>
    ///        <link>http://example.com/home?t=global</link>
    ///        <generator>Vernissage 1.0.0-buildx</generator>
    ///        <lastBuildDate>Fri, 14 Feb 2025 12:44:01 +0000</lastBuildDate>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7471254701275615610</guid>
    ///            <pubDate>Fri, 14 Feb 2025 12:44:01 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7471254701275615610</link>
    ///            <description>&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///                <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///                <media:rating scheme="urn:simple">adult</media:rating>
    ///            </media:content>
    ///        </item>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7470218914077610911</guid>
    ///            <pubDate>Tue, 11 Feb 2025 17:44:38 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7470218914077610911</link>
    ///            <description>&lt;p&gt;AAAAAA&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/a72ae8cdc2fa4461abaacc24af903f03.jpg" medium="image" type="image/jpeg">
    ///                <media:description type="plain"></media:description>
    ///                <media:rating scheme="urn:simple">nonadult</media:rating>
    ///            </media:content>
    ///        </item>
    ///    </channel>
    /// </rss>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: RSS feed with globla statuses.
    @Sendable
    func global(request: Request) async throws -> Response {
        let appplicationSettings = request.application.settings.cached
        if appplicationSettings?.showLocalTimelineForAnonymous == false {
            throw ActionsForbiddenError.localTimelineForbidden
        }
        
        let rssService = request.application.services.rssService
        let xmlDocument = try await rssService.global(on: request.executionContext)
        return try await createRssResponse(xmlDocument, request)
    }
    
    /// Returns RSS feed with trending statuses.
    ///
    /// > Important: Endpoint URL: `/rss/trending/:period`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/rss/trending/daily" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <rss xmlns:webfeeds="http://webfeeds.org/rss/1.0" xmlns:media="http://search.yahoo.com/mrss/" version="2.0">
    ///    <channel>
    ///        <title>Trending posts (daily)</title>
    ///        <description>Trending posts on the instance https://example.com</description>
    ///        <link>http://example.com//trending?trending=statuses&period=daily</link>
    ///        <generator>Vernissage 1.0.0-buildx</generator>
    ///        <lastBuildDate>Fri, 14 Feb 2025 12:44:01 +0000</lastBuildDate>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7471254701275615610</guid>
    ///            <pubDate>Fri, 14 Feb 2025 12:44:01 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7471254701275615610</link>
    ///            <description>&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///                <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///                <media:rating scheme="urn:simple">adult</media:rating>
    ///            </media:content>
    ///        </item>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7470218914077610911</guid>
    ///            <pubDate>Tue, 11 Feb 2025 17:44:38 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7470218914077610911</link>
    ///            <description>&lt;p&gt;AAAAAA&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/a72ae8cdc2fa4461abaacc24af903f03.jpg" medium="image" type="image/jpeg">
    ///                <media:description type="plain"></media:description>
    ///                <media:rating scheme="urn:simple">nonadult</media:rating>
    ///            </media:content>
    ///        </item>
    ///    </channel>
    /// </rss>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: RSS feed with globla statuses.
    @Sendable
    func trending(request: Request) async throws -> Response {
        let appplicationSettings = request.application.settings.cached
        if appplicationSettings?.showTrendingForAnonymous == false {
            throw ActionsForbiddenError.trendingForbidden
        }
        
        let periodString = request.parameters.get("period") ?? "daily"
        let period = TrendingStatusPeriodDto(rawValue: periodString) ?? .daily
        
        let rssService = request.application.services.rssService
        let xmlDocument = try await rssService.trending(period: period.translate(), on: request.executionContext)
        return try await createRssResponse(xmlDocument, request)
    }
    
    /// Returns RSS feed with featured statuses.
    ///
    /// > Important: Endpoint URL: `/rss/featured`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/rss/featured" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <rss xmlns:webfeeds="http://webfeeds.org/rss/1.0" xmlns:media="http://search.yahoo.com/mrss/" version="2.0">
    ///    <channel>
    ///        <title>Editor's choice timeline</title>
    ///        <description>All featured public posts</description>
    ///        <link>http://example.com/editors?tab=statuses</link>
    ///        <generator>Vernissage 1.0.0-buildx</generator>
    ///        <lastBuildDate>Fri, 14 Feb 2025 12:44:01 +0000</lastBuildDate>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7471254701275615610</guid>
    ///            <pubDate>Fri, 14 Feb 2025 12:44:01 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7471254701275615610</link>
    ///            <description>&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///                <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///                <media:rating scheme="urn:simple">adult</media:rating>
    ///            </media:content>
    ///        </item>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7470218914077610911</guid>
    ///            <pubDate>Tue, 11 Feb 2025 17:44:38 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7470218914077610911</link>
    ///            <description>&lt;p&gt;AAAAAA&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/a72ae8cdc2fa4461abaacc24af903f03.jpg" medium="image" type="image/jpeg">
    ///                <media:description type="plain"></media:description>
    ///                <media:rating scheme="urn:simple">nonadult</media:rating>
    ///            </media:content>
    ///        </item>
    ///    </channel>
    /// </rss>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: RSS feed with featured statuses.
    @Sendable
    func featured(request: Request) async throws -> Response {
        let appplicationSettings = request.application.settings.cached
        if appplicationSettings?.showEditorsChoiceForAnonymous == false {
            throw ActionsForbiddenError.editorsStatusesChoiceForbidden
        }
        
        let rssService = request.application.services.rssService
        let xmlDocument = try await rssService.featured(on: request.executionContext)
        return try await createRssResponse(xmlDocument, request)
    }
    
    /// Returns RSS feed with categories statuses.
    ///
    /// > Important: Endpoint URL: `/rss/categories/:category`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/rss/categories/Abstract" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <rss xmlns:webfeeds="http://webfeeds.org/rss/1.0" xmlns:media="http://search.yahoo.com/mrss/" version="2.0">
    ///    <channel>
    ///        <title>Abstract</title>
    ///        <description>Public post for category Abstract</description>
    ///        <link>http://example.com/categories/Abstract</link>
    ///        <generator>Vernissage 1.0.0-buildx</generator>
    ///        <lastBuildDate>Fri, 14 Feb 2025 12:44:01 +0000</lastBuildDate>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7471254701275615610</guid>
    ///            <pubDate>Fri, 14 Feb 2025 12:44:01 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7471254701275615610</link>
    ///            <description>&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///                <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///                <media:rating scheme="urn:simple">adult</media:rating>
    ///            </media:content>
    ///        </item>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7470218914077610911</guid>
    ///            <pubDate>Tue, 11 Feb 2025 17:44:38 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7470218914077610911</link>
    ///            <description>&lt;p&gt;AAAAAA&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/a72ae8cdc2fa4461abaacc24af903f03.jpg" medium="image" type="image/jpeg">
    ///                <media:description type="plain"></media:description>
    ///                <media:rating scheme="urn:simple">nonadult</media:rating>
    ///            </media:content>
    ///        </item>
    ///    </channel>
    /// </rss>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: RSS feed with featured statuses.
    @Sendable
    func categories(request: Request) async throws -> Response {
        let appplicationSettings = request.application.settings.cached
        if appplicationSettings?.showCategoriesForAnonymous == false {
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
        
        let rssService = request.application.services.rssService
        let xmlDocument = try await rssService.categories(category: category, on: request.executionContext)
        return try await createRssResponse(xmlDocument, request)
    }
    
    /// Returns RSS feed with statuses with hashtag.
    ///
    /// > Important: Endpoint URL: `/rss/hashtags/:hashtag`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/rss/hashtags/photography" \
    /// -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <rss xmlns:webfeeds="http://webfeeds.org/rss/1.0" xmlns:media="http://search.yahoo.com/mrss/" version="2.0">
    ///    <channel>
    ///        <title>#photograpghy</title>
    ///        <description>Public post for tag #photography</description>
    ///        <link>http://example.com/hashtags/photography</link>
    ///        <generator>Vernissage 1.0.0-buildx</generator>
    ///        <lastBuildDate>Fri, 14 Feb 2025 12:44:01 +0000</lastBuildDate>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7471254701275615610</guid>
    ///            <pubDate>Fri, 14 Feb 2025 12:44:01 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7471254701275615610</link>
    ///            <description>&lt;p&gt;mild male nudity, drastically portrayed despair&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/3e5b9671764141159fb3e54c295aaec3.jpg" type="image/jpeg" medium="image">
    ///                <media:description type="plain">mild male nudity, drastically portrayed despair</media:description>
    ///                <media:rating scheme="urn:simple">adult</media:rating>
    ///            </media:content>
    ///        </item>
    ///        <item>
    ///            <guid isPermaLink="true">http://example.com/@johndoe/7470218914077610911</guid>
    ///            <pubDate>Tue, 11 Feb 2025 17:44:38 +0000</pubDate>
    ///            <link>http://example.com/@johndoe/7470218914077610911</link>
    ///            <description>&lt;p&gt;AAAAAA&lt;/p&gt;</description>
    ///            <media:content url="https://example.com/vernissage-test/a72ae8cdc2fa4461abaacc24af903f03.jpg" medium="image" type="image/jpeg">
    ///                <media:description type="plain"></media:description>
    ///                <media:rating scheme="urn:simple">nonadult</media:rating>
    ///            </media:content>
    ///        </item>
    ///    </channel>
    /// </rss>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: RSS feed with statuses with hashtag.
    @Sendable
    func hashtags(request: Request) async throws -> Response {
        let appplicationSettings = request.application.settings.cached
        if appplicationSettings?.showHashtagsForAnonymous == false {
            throw ActionsForbiddenError.hashtagsForbidden
        }
        
        guard let hashtag = request.parameters.get("hashtag") else {
            throw Abort(.badRequest)
        }
                
        let rssService = request.application.services.rssService
        let xmlDocument = try await rssService.hashtags(hashtag: hashtag, on: request.executionContext)
        return try await createRssResponse(xmlDocument, request)
    }
    
    private func createRssResponse(_ xmlDocument: String, _ request: Request) async throws -> Response {
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentType, value: "application/rss+xml; charset=utf-8")
        
        return try await xmlDocument.encodeResponse(status: .ok, headers: headers, for: request)
    }
}
