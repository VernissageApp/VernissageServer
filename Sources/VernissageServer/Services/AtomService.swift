//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SwiftSoup

extension Application.Services {
    struct AtomServiceKey: StorageKey {
        typealias Value = AtomServiceType
    }

    var atomService: AtomServiceType {
        get {
            self.application.storage[AtomServiceKey.self] ?? AtomService()
        }
        nonmutating set {
            self.application.storage[AtomServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol AtomServiceType: Sendable {
    func feed(for user: User, on context: ExecutionContext) async throws -> String
    func local(on context: ExecutionContext) async throws -> String
    func global(on context: ExecutionContext) async throws -> String
    func trending(period: TrendingPeriod, on context: ExecutionContext) async throws -> String
    func featured(on context: ExecutionContext) async throws -> String
    func categories(category: Category, on context: ExecutionContext) async throws -> String
    func hashtags(hashtag: String, on context: ExecutionContext) async throws -> String
}

/// A service for managing Atom feeds returned from the system.
final class AtomService: AtomServiceType {
    private let maximumNumnerOfItems = 40

    func feed(for user: User, on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let usersService = context.application.services.usersService

        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumnerOfItems)
        let linkableStatuses = try await usersService.publicStatuses(for: user.requireID(), linkableParams: linkableParams, on: context)
        
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<feed xmlns=\"http://www.w3.org/2005/Atom\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        
        // Add feed header.
        xmlString += "<title>\(user.name ?? user.userName)</title>"
        xmlString += "<subtitle>Public posts from @\(user.account)</subtitle>"
        xmlString += "<link href=\"\(user.url ?? "\(baseAddress)/@\(user.userName)")\" />"
        xmlString += "<generator version=\"\(Constants.version)\">Vernissage</generator>"
        xmlString += "<id>\(baseAddress)/atom/users/@\(user.userName)</id>"
        xmlString += "<link href=\"\(baseAddress)/atom/users/@\(user.userName)\" rel=\"self\" type=\"application/atom+xml\" />"
        
        if let firstStatus = linkableStatuses.data.first, let lastDate = firstStatus.createdAt {
            xmlString += "<updated>\(lastDate.toISO8601String())</updated>"
        }
        
        // Author element.
        xmlString += "<author>"
        xmlString += "<name>\(user.name ?? user.userName)</name>"
        xmlString += "<uri>\(user.url ?? "\(baseAddress)/@\(user.userName)")</uri>"
        xmlString += "</author>"
        
        // User icon.
        if let avatarUrl = UserDto.getAvatarUrl(user: user, baseImagesPath: baseImagesPath) {
            xmlString += "<icon>\(avatarUrl)</icon>"
            xmlString += "<logo>\(avatarUrl)</logo>"
        }

        // Add status items.
        for status in linkableStatuses.data {
            xmlString += self.createEntry(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }
        
        xmlString += "</feed>"
        return xmlString
    }
    
    func local(on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumnerOfItems)
        let linkableStatuses = try await timelineService.public(linkableParams: linkableParams, onlyLocal: true, on: context.db)
        
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<feed xmlns=\"http://www.w3.org/2005/Atom\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        
        // Add feed header.
        xmlString += "<title>Local timeline</title>"
        xmlString += "<subtitle>Public posts from the instance \(baseAddress)</subtitle>"
        xmlString += "<link href=\"\(baseAddress)/home?t=local\" />"
        xmlString += "<generator version=\"\(Constants.version)\">Vernissage</generator>"
        xmlString += "<id>\(baseAddress)/atom/local</id>"
        xmlString += "<link href=\"\(baseAddress)/atom/local\" rel=\"self\" type=\"application/atom+xml\" />"

        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            xmlString += "<updated>\(lastDate.toISO8601String())</updated>"
        }
                
        // Add status items.
        for status in linkableStatuses {
            xmlString += self.createEntry(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }
 
        xmlString += "</feed>"
        return xmlString
    }
    
    func global(on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumnerOfItems)
        let linkableStatuses = try await timelineService.public(linkableParams: linkableParams, onlyLocal: false, on: context.db)
        
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<feed xmlns=\"http://www.w3.org/2005/Atom\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        
        // Add feed header.
        xmlString += "<title>Global timeline</title>"
        xmlString += "<subtitle>All public posts</subtitle>"
        xmlString += "<link href=\"\(baseAddress)/home?t=global\" />"
        xmlString += "<generator version=\"\(Constants.version)\">Vernissage</generator>"
        xmlString += "<id>\(baseAddress)/atom/global</id>"
        xmlString += "<link href=\"\(baseAddress)/atom/global\" rel=\"self\" type=\"application/atom+xml\" />"

        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            xmlString += "<updated>\(lastDate.toISO8601String())</updated>"
        }
                
        // Add status items.
        for status in linkableStatuses {
            xmlString += self.createEntry(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }

        xmlString += "</feed>"
        return xmlString
    }
    
    func trending(period: TrendingPeriod, on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let trendingService = context.application.services.trendingService

        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumnerOfItems)
        let linkableStatuses = try await trendingService.statuses(linkableParams: linkableParams, period: period, on: context.db)
        
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<feed xmlns=\"http://www.w3.org/2005/Atom\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        
        // Add feed header.
        xmlString += "<title>Trending posts (\(period))</title>"
        xmlString += "<subtitle>Trending posts on the instance \(baseAddress)</subtitle>"
        xmlString += "<link href=\"\(baseAddress)/trending?trending=statuses&amp;period=\(period)\" />"
        xmlString += "<generator version=\"\(Constants.version)\">Vernissage</generator>"
        xmlString += "<id>\(baseAddress)/atom/trending/\(period)</id>"
        xmlString += "<link href=\"\(baseAddress)/atom/trending/\(period)\" rel=\"self\" type=\"application/atom+xml\" />"

        if let firstStatus = linkableStatuses.data.first, let lastDate = firstStatus.createdAt {
            xmlString += "<updated>\(lastDate.toISO8601String())</updated>"
        }
                
        // Add status items.
        for status in linkableStatuses.data {
            xmlString += self.createEntry(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }
        
        xmlString += "</feed>"
        return xmlString
    }
    
    func featured(on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumnerOfItems)
        let linkableStatuses = try await timelineService.featuredStatuses(linkableParams: linkableParams, onlyLocal: false, on: context.db)
                
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<feed xmlns=\"http://www.w3.org/2005/Atom\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        
        // Add feed header.
        xmlString += "<title>Editor's choice timeline</title>"
        xmlString += "<subtitle>All featured public posts</subtitle>"
        xmlString += "<link href=\"\(baseAddress)/editors?tab=statuses\" />"
        xmlString += "<generator version=\"\(Constants.version)\">Vernissage</generator>"
        xmlString += "<id>\(baseAddress)/atom/featured</id>"
        xmlString += "<link href=\"\(baseAddress)/atom/featured\" rel=\"self\" type=\"application/atom+xml\" />"

        if let firstStatus = linkableStatuses.data.first, let lastDate = firstStatus.createdAt {
            xmlString += "<updated>\(lastDate.toISO8601String())</updated>"
        }
                
        // Add status items.
        for status in linkableStatuses.data {
            xmlString += self.createEntry(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }

        xmlString += "</feed>"
        return xmlString
    }
    
    func categories(category: Category, on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumnerOfItems)
        let linkableStatuses = try await timelineService.category(linkableParams: linkableParams, categoryId: category.requireID(), onlyLocal: false, on: context.db)
        
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<feed xmlns=\"http://www.w3.org/2005/Atom\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        
        // Add feed header.
        xmlString += "<title>\(category.name)</title>"
        xmlString += "<subtitle>Public post for category \(category.name)</subtitle>"
        xmlString += "<link href=\"\(baseAddress)/categories/\(category.name)\" />"
        xmlString += "<generator version=\"\(Constants.version)\">Vernissage</generator>"
        xmlString += "<id>\(baseAddress)/atom/categories/\(category.name)</id>"
        xmlString += "<link href=\"\(baseAddress)/atom/categories/\(category.name)\" rel=\"self\" type=\"application/atom+xml\" />"

        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            xmlString += "<updated>\(lastDate.toISO8601String())</updated>"
        }
                
        // Add status items.
        for status in linkableStatuses {
            xmlString += self.createEntry(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }
        
        xmlString += "</feed>"
        return xmlString
    }
    
    func hashtags(hashtag: String, on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseImagesPath = storageService.getBaseImagesPath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: self.maximumNumnerOfItems)
        let linkableStatuses = try await timelineService.hashtags(linkableParams: linkableParams, hashtag: hashtag, onlyLocal: false, on: context.db)
        
        // Start creating XML string.
        var xmlString = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        xmlString += "<feed xmlns=\"http://www.w3.org/2005/Atom\" xmlns:media=\"http://search.yahoo.com/mrss/\">"
        
        // Add feed header.
        xmlString += "<title>#\(hashtag)</title>"
        xmlString += "<subtitle>Public post for tag #\(hashtag)</subtitle>"
        xmlString += "<link href=\"\(baseAddress)/tags/\(hashtag)\" />"
        xmlString += "<generator version=\"\(Constants.version)\">Vernissage</generator>"
        xmlString += "<id>\(baseAddress)/atom/hashtags/\(hashtag)</id>"
        xmlString += "<link href=\"\(baseAddress)/atom/hashtags/\(hashtag)\" rel=\"self\" type=\"application/atom+xml\" />"

        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            xmlString += "<updated>\(lastDate.toISO8601String())</updated>"
        }
                
        // Add status items.
        for status in linkableStatuses {
            xmlString += self.createEntry(status: status, baseAddress: baseAddress, baseImagesPath: baseImagesPath)
        }

        xmlString += "</feed>"
        return xmlString
    }
    
    private func createEntry(status: Status, baseAddress: String, baseImagesPath: String) -> String {
        let outputSettings = OutputSettings().charset(String.Encoding.utf8).escapeMode(Entities.EscapeMode.xhtml)
        var entry = "<entry>"
        
        entry += "<id>\(Entities.escape(status.activityPubUrl, outputSettings))</id>"
        entry += "<title>\(status.user.name ?? status.user.userName) photo</title>"
        entry += "<link href=\"\(Entities.escape(status.activityPubUrl, outputSettings))\" />"
        
        if let pubDate = status.createdAt {
            entry += "<updated>\(pubDate.toISO8601String())</updated>"
            entry += "<published>\(pubDate.toISO8601String())</published>"
        }
        
        // Author element.
        entry += "<author>"
        entry += "<name>\(status.user.name ?? status.user.userName)</name>"
        entry += "<uri>\(status.user.url ?? "\(baseAddress)/@\(status.user.userName)")</uri>"
        entry += "</author>"
        
        // Status note.
        if let entryContent = status.isLocal ? status.note?.html(baseAddress: baseAddress, wrapInParagraph: true) : status.note {
            let escapedEntryContent = Entities.escape(entryContent, outputSettings)
            if !escapedEntryContent.isEmpty {
                entry += "<content type=\"html\">\(escapedEntryContent)</content>"
            }
        }
        
        // Add image element.
        if let attachment = status.attachments.first {
            
            let imageUrl = baseImagesPath.finished(with: "/") + attachment.originalFile.fileName
            entry += "<media:content url=\"\(imageUrl)\" type=\"image/jpeg\" medium=\"image\">"
                        
            if let description = attachment.description {
                entry += "<media:description type=\"plain\">\(Entities.escape(description, outputSettings))</media:description>"
            }
            
            if status.contentWarning != nil && status.contentWarning?.isEmpty == false {
                entry += "<media:rating scheme=\"urn:simple\">adult</media:rating>"
            } else {
                entry += "<media:rating scheme=\"urn:simple\">nonadult</media:rating>"
            }
                                    
            entry += "</media:content>"
            
            if let license = attachment.license?.name, !license.isEmpty {
                entry += "<rights type=\"text\">\(license)</rights>"
            }
        }
        
        // Add categories elements.
        for tag in status.hashtags {
            entry += "<category term=\"\(tag.hashtag)\" />"
        }
        
        entry += "</entry>"
        return entry
    }
}
