//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SwiftSoup

extension Application.Services {
    struct RssServiceKey: StorageKey {
        typealias Value = RssServiceType
    }

    var rssService: RssServiceType {
        get {
            self.application.storage[RssServiceKey.self] ?? RssService()
        }
        nonmutating set {
            self.application.storage[RssServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol RssServiceType: Sendable {
    /// Generates an RSS feed for the given user.
    ///
    /// - Parameters:
    ///   - user: The user for whom the RSS feed will be generated.
    ///   - context: The execution context providing access to services and the database.
    /// - Returns: An RSS feed as an XML string.
    /// - Throws: An error if feed generation fails.
    func feed(for user: User, on context: ExecutionContext) async throws -> String

    /// Generates an RSS feed for the local timeline.
    ///
    /// - Parameter context: The execution context providing access to services and the database.
    /// - Returns: An RSS feed of local public posts as an XML string.
    /// - Throws: An error if feed generation fails.
    func local(on context: ExecutionContext) async throws -> String

    /// Generates an RSS feed for the global timeline.
    ///
    /// - Parameter context: The execution context providing access to services and the database.
    /// - Returns: An RSS feed of all public posts as an XML string.
    /// - Throws: An error if feed generation fails.
    func global(on context: ExecutionContext) async throws -> String

    /// Generates an RSS feed for trending posts in a given period.
    ///
    /// - Parameters:
    ///   - period: The trending period for which to fetch posts.
    ///   - context: The execution context providing access to services and the database.
    /// - Returns: An RSS feed of trending posts as an XML string.
    /// - Throws: An error if feed generation fails.
    func trending(period: TrendingPeriod, on context: ExecutionContext) async throws -> String

    /// Generates an RSS feed for featured posts.
    ///
    /// - Parameter context: The execution context providing access to services and the database.
    /// - Returns: An RSS feed of featured public posts as an XML string.
    /// - Throws: An error if feed generation fails.
    func featured(on context: ExecutionContext) async throws -> String

    /// Generates an RSS feed for a specified category.
    ///
    /// - Parameters:
    ///   - category: The category for which to fetch posts.
    ///   - context: The execution context providing access to services and the database.
    /// - Returns: An RSS feed of public posts for the given category as an XML string.
    /// - Throws: An error if feed generation fails.
    func categories(category: Category, on context: ExecutionContext) async throws -> String

    /// Generates an RSS feed for a specified hashtag.
    ///
    /// - Parameters:
    ///   - hashtag: The hashtag for which to fetch posts.
    ///   - context: The execution context providing access to services and the database.
    /// - Returns: An RSS feed of public posts containing the given hashtag as an XML string.
    /// - Throws: An error if feed generation fails.
    func hashtags(hashtag: String, on context: ExecutionContext) async throws -> String
}

/// A service for managing RSS feeds returned from the system.
final class RssService: RssServiceType {
    private let maximumNumberOfItems = 40

    func feed(for user: User, on context: ExecutionContext) async throws -> String {
        let applicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let usersService = context.application.services.usersService

        let baseAddress = applicationSettings?.baseAddress ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumberOfItems)
        let linkableStatuses = try await usersService.publicStatuses(for: user.requireID(), linkableParams: linkableParams, on: context)
        
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<rss version=\"2.0\" xmlns:webfeeds=\"http://webfeeds.org/rss/1.0\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        xmlString += "<channel>"
        
        // Add feed header.
        xmlString += "<title>\(user.name ?? user.userName)</title>"
        xmlString += "<description>Public posts from @\(user.account)</description>"
        xmlString += "<link>\(user.url ?? "\(baseAddress)/@\(user.userName)")</link>"
        xmlString += "<generator>Vernissage \(Constants.version)</generator>"
        
        if let firstStatus = linkableStatuses.data.first, let lastDate = firstStatus.createdAt {
            xmlString += "<lastBuildDate>\(lastDate.toRFC822String())</lastBuildDate>"
        }
            
        // User image.
        if let avatarUrl = UserDto.getAvatarUrl(user: user, baseImagesPath: baseImagesPath) {
            xmlString += "<image>"
            xmlString += "<url>\(avatarUrl)</url>"
            xmlString += "<title>\(user.name ?? user.userName)</title>"
            xmlString += "<link>\(user.url ?? "\(baseAddress)/@\(user.userName)")</link>"
                        
            xmlString += "</image>"
            xmlString += "<webfeeds:icon>\(avatarUrl)</webfeeds:icon>"
        }
        
        // Add status items.
        for status in linkableStatuses.data {
            xmlString += self.createItem(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }
        
        xmlString += "</channel>"
        xmlString += "</rss>"
        return xmlString
    }
    
    func local(on context: ExecutionContext) async throws -> String {
        let applicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = applicationSettings?.baseAddress ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumberOfItems)
        let linkableStatuses = try await timelineService.public(linkableParams: linkableParams, onlyLocal: true, on: context.db)
        
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<rss version=\"2.0\" xmlns:webfeeds=\"http://webfeeds.org/rss/1.0\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        xmlString += "<channel>"
        
        // Add feed header.
        xmlString += "<title>Local timeline</title>"
        xmlString += "<description>Public posts from the instance \(baseAddress)</description>"
        xmlString += "<link>\(baseAddress)/home?t=local</link>"
        xmlString += "<generator>Vernissage \(Constants.version)</generator>"
        
        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            xmlString += "<lastBuildDate>\(lastDate.toRFC822String())</lastBuildDate>"
        }
        
        // Add status items.
        for status in linkableStatuses {
            xmlString += self.createItem(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }
                
        xmlString += "</channel>"
        xmlString += "</rss>"
        return xmlString
    }
    
    func global(on context: ExecutionContext) async throws -> String {
        let applicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = applicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumberOfItems)
        let linkableStatuses = try await timelineService.public(linkableParams: linkableParams, onlyLocal: false, on: context.db)
        
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<rss version=\"2.0\" xmlns:webfeeds=\"http://webfeeds.org/rss/1.0\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        xmlString += "<channel>"
        
        // Add feed header.
        xmlString += "<title>Global timeline</title>"
        xmlString += "<description>All public posts</description>"
        xmlString += "<link>\(baseAddress)/home?t=global</link>"
        xmlString += "<generator>Vernissage \(Constants.version)</generator>"
        
        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            xmlString += "<lastBuildDate>\(lastDate.toRFC822String())</lastBuildDate>"
        }
        
        // Add status items.
        for status in linkableStatuses {
            xmlString += self.createItem(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }
        
        xmlString += "</channel>"
        xmlString += "</rss>"
        return xmlString
    }
    
    func trending(period: TrendingPeriod, on context: ExecutionContext) async throws -> String {
        let applicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let trendingService = context.application.services.trendingService

        let baseAddress = applicationSettings?.baseAddress ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumberOfItems)
        let linkableStatuses = try await trendingService.statuses(linkableParams: linkableParams, period: period, on: context.db)
        
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<rss version=\"2.0\" xmlns:webfeeds=\"http://webfeeds.org/rss/1.0\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        xmlString += "<channel>"
        
        // Add feed header.
        xmlString += "<title>Trending posts (\(period))</title>"
        xmlString += "<description>Trending posts on the instance \(baseAddress)</description>"
        xmlString += "<link>\(baseAddress)/trending?trending=statuses&amp;period=\(period)</link>"
        xmlString += "<generator>Vernissage \(Constants.version)</generator>"
        
        if let firstStatus = linkableStatuses.data.first, let lastDate = firstStatus.createdAt {
            xmlString += "<lastBuildDate>\(lastDate.toRFC822String())</lastBuildDate>"
        }
        
        // Add status items.
        for status in linkableStatuses.data {
            xmlString += self.createItem(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }

        xmlString += "</channel>"
        xmlString += "</rss>"
        return xmlString
    }
    
    func featured(on context: ExecutionContext) async throws -> String {
        let applicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = applicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumberOfItems)
        let linkableStatuses = try await timelineService.featuredStatuses(linkableParams: linkableParams, onlyLocal: false, on: context.db)
        
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<rss version=\"2.0\" xmlns:webfeeds=\"http://webfeeds.org/rss/1.0\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        xmlString += "<channel>"
        
        // Add feed header.
        xmlString += "<title>Editor's choice timeline</title>"
        xmlString += "<description>All featured public posts</description>"
        xmlString += "<link>\(baseAddress)/editors?tab=statuses</link>"
        xmlString += "<generator>Vernissage \(Constants.version)</generator>"
        
        if let firstStatus = linkableStatuses.data.first, let lastDate = firstStatus.createdAt {
            xmlString += "<lastBuildDate>\(lastDate.toRFC822String())</lastBuildDate>"
        }
        
        // Add status items.
        for status in linkableStatuses.data {
            xmlString += self.createItem(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }
                
        xmlString += "</channel>"
        xmlString += "</rss>"
        return xmlString
    }
    
    func categories(category: Category, on context: ExecutionContext) async throws -> String {
        let applicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = applicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumberOfItems)
        let linkableStatuses = try await timelineService.category(linkableParams: linkableParams, categoryId: category.requireID(), onlyLocal: false, on: context.db)
        
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<rss version=\"2.0\" xmlns:webfeeds=\"http://webfeeds.org/rss/1.0\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        xmlString += "<channel>"
        
        // Add feed header.
        xmlString += "<title>\(category.name)</title>"
        xmlString += "<description>Public post for category \(category.name)</description>"
        xmlString += "<link>\(baseAddress)/categories/\(category.name)</link>"
        xmlString += "<generator>Vernissage \(Constants.version)</generator>"
        
        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            xmlString += "<lastBuildDate>\(lastDate.toRFC822String())</lastBuildDate>"
        }
        
        // Add status items.
        for status in linkableStatuses {
            xmlString += self.createItem(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }
                
        xmlString += "</channel>"
        xmlString += "</rss>"
        return xmlString
    }
    
    func hashtags(hashtag: String, on context: ExecutionContext) async throws -> String {
        let applicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = applicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumberOfItems)
        let linkableStatuses = try await timelineService.hashtags(linkableParams: linkableParams, hashtag: hashtag, onlyLocal: false, on: context.db)
        
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<rss version=\"2.0\" xmlns:webfeeds=\"http://webfeeds.org/rss/1.0\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        xmlString += "<channel>"
        
        // Add feed header.
        xmlString += "<title>#\(hashtag)</title>"
        xmlString += "<description>Public post for tag #\(hashtag)</description>"
        xmlString += "<link>\(baseAddress)/tags/\(hashtag)</link>"
        xmlString += "<generator>Vernissage \(Constants.version)</generator>"
        
        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            xmlString += "<lastBuildDate>\(lastDate.toRFC822String())</lastBuildDate>"
        }
        
        // Add status items.
        for status in linkableStatuses {
            xmlString += self.createItem(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }

        xmlString += "</channel>"
        xmlString += "</rss>"
        return xmlString
    }
    
    private func createItem(status: Status, baseAddress: String, baseImagesPath: String) -> String {
        let outputSettings = OutputSettings().charset(String.Encoding.utf8).escapeMode(Entities.EscapeMode.xhtml)

        var item = "<item>"
        item += "<guid isPermaLink=\"true\">\(Entities.escape(status.activityPubUrl, outputSettings))</guid>"
        
        if let pubDate = status.createdAt {
            item += "<pubDate>\(pubDate.toRFC822String())</pubDate>"
        }

        item += "<link>\(Entities.escape(status.activityPubUrl, outputSettings))</link>"
        
        // Status note.
        if let entryContent = status.isLocal ? status.note?.html(baseAddress: baseAddress, wrapInParagraph: true) : status.note {
            let escapedEntryContent = Entities.escape(entryContent, outputSettings)
            item += "<description>\(escapedEntryContent)</description>"
        }
                        
        // Add image element.
        if let attachment = status.attachments.first {
            
            let imageUrl = baseImagesPath.finished(with: "/") + attachment.originalFile.fileName
            item += "<media:content url=\"\(imageUrl)\" type=\"image/jpeg\" medium=\"image\">"
                        
            if let description = attachment.description {
                item += "<media:description type=\"plain\">\(Entities.escape(description, outputSettings))</media:description>"
            }
            
            if status.contentWarning != nil && status.contentWarning?.isEmpty == false {
                item += "<media:rating scheme=\"urn:simple\">adult</media:rating>"
            } else {
                item += "<media:rating scheme=\"urn:simple\">nonadult</media:rating>"
            }
            
            item += "</media:content>"
        }
        
        // Add categories elements.
        for tag in status.hashtags {
            item += "<category>\(tag.hashtag)</category>"
        }
        
        item += "</item>"
        return item
    }
}
