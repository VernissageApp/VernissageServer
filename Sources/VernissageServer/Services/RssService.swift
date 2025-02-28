//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

import Vapor
import Fluent

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
    func feed(for user: User, on context: ExecutionContext) async throws -> String
    func local(on context: ExecutionContext) async throws -> String
    func global(on context: ExecutionContext) async throws -> String
    func trending(period: TrendingPeriod, on context: ExecutionContext) async throws -> String
    func featured(on context: ExecutionContext) async throws -> String
    func categories(category: Category, on context: ExecutionContext) async throws -> String
    func hashtags(hashtag: String, on context: ExecutionContext) async throws -> String
}

/// A service for managing RSS feeds returned from the system.
final class RssService: RssServiceType {
    func feed(for user: User, on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let usersService = context.application.services.usersService

        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 20)
        let linkableStatuses = try await usersService.publicStatuses(for: user.requireID(), linkableParams: linkableParams, on: context)
        
        // Create first node in the document.
        let rss = XMLElement(name: "rss")
        rss.setAttributesWith(["version":"2.0", "xmlns:webfeeds": "http://webfeeds.org/rss/1.0", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: rss)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
        
        // Add channel node to the rss node.
        let channel = XMLElement(name: "channel")
        rss.addChild(channel)
    
        // Add RSS header.
        channel.addChild(XMLElement(name: "title", stringValue: user.name ?? user.userName))
        channel.addChild(XMLElement(name: "description", stringValue: "Public posts from @\(user.account)"))
        channel.addChild(XMLElement(name: "link", stringValue: user.url ?? "\(baseAddress)/@\(user.userName)"))
        channel.addChild(XMLElement(name: "generator", stringValue: "Vernissage \(Constants.version)"))
        
        if let firstStatus = linkableStatuses.data.first, let lastDate = firstStatus.createdAt {
            channel.addChild(XMLElement(name: "lastBuildDate", stringValue: lastDate.toRFC822String()))
        }
        
        // User image.
        if let avatarUrl = UserDto.getAvatarUrl(user: user, baseStoragePath: baseStoragePath) {
            let image = XMLElement(name: "image")
            
            let url = XMLElement(name: "url", stringValue: avatarUrl)
            image.addChild(url)
            
            let title = XMLElement(name: "title", stringValue: user.name ?? user.userName)
            image.addChild(title)
            
            let link = XMLElement(name: "link", stringValue: user.url ?? "\(baseAddress)/@\(user.userName)")
            image.addChild(link)
            
            channel.addChild(image)
            channel.addChild(XMLElement(name: "webfeeds:icon", stringValue: avatarUrl))
        }
        
        // Add status items.
        for status in linkableStatuses.data {
            let item = self.createItem(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            channel.addChild(item)
        }
        
        return xmlDocument.xmlString
    }
    
    func local(on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 20)
        let linkableStatuses = try await timelineService.public(linkableParams: linkableParams, onlyLocal: true, on: context.db)
        
        // Create first node in the document.
        let rss = XMLElement(name: "rss")
        rss.setAttributesWith(["version":"2.0", "xmlns:webfeeds": "http://webfeeds.org/rss/1.0", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: rss)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
        
        // Add channel node to the rss node.
        let channel = XMLElement(name: "channel")
        rss.addChild(channel)
    
        // Add RSS header.
        channel.addChild(XMLElement(name: "title", stringValue: "Local timeline"))
        channel.addChild(XMLElement(name: "description", stringValue: "Public posts from the instance \(baseAddress)"))
        channel.addChild(XMLElement(name: "link", stringValue: "\(baseAddress)/home?t=local"))
        channel.addChild(XMLElement(name: "generator", stringValue: "Vernissage \(Constants.version)"))
        
        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            channel.addChild(XMLElement(name: "lastBuildDate", stringValue: lastDate.toRFC822String()))
        }
                
        // Add status items.
        for status in linkableStatuses {
            let item = self.createItem(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            channel.addChild(item)
        }
        
        return xmlDocument.xmlString
    }
    
    func global(on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 20)
        let linkableStatuses = try await timelineService.public(linkableParams: linkableParams, onlyLocal: false, on: context.db)
        
        // Create first node in the document.
        let rss = XMLElement(name: "rss")
        rss.setAttributesWith(["version":"2.0", "xmlns:webfeeds": "http://webfeeds.org/rss/1.0", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: rss)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
        
        // Add channel node to the rss node.
        let channel = XMLElement(name: "channel")
        rss.addChild(channel)
    
        // Add RSS header.
        channel.addChild(XMLElement(name: "title", stringValue: "Global timeline"))
        channel.addChild(XMLElement(name: "description", stringValue: "All public posts"))
        channel.addChild(XMLElement(name: "link", stringValue: "\(baseAddress)/home?t=global"))
        channel.addChild(XMLElement(name: "generator", stringValue: "Vernissage \(Constants.version)"))
        
        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            channel.addChild(XMLElement(name: "lastBuildDate", stringValue: lastDate.toRFC822String()))
        }
                
        // Add status items.
        for status in linkableStatuses {
            let item = self.createItem(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            channel.addChild(item)
        }
        
        return xmlDocument.xmlString
    }
    
    func trending(period: TrendingPeriod, on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let trendingService = context.application.services.trendingService

        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 20)
        let linkableStatuses = try await trendingService.statuses(linkableParams: linkableParams, period: period, on: context.db)
        
        // Create first node in the document.
        let rss = XMLElement(name: "rss")
        rss.setAttributesWith(["version":"2.0", "xmlns:webfeeds": "http://webfeeds.org/rss/1.0", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: rss)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
        
        // Add channel node to the rss node.
        let channel = XMLElement(name: "channel")
        rss.addChild(channel)
    
        // Add RSS header.
        channel.addChild(XMLElement(name: "title", stringValue: "Trending posts (\(period))"))
        channel.addChild(XMLElement(name: "description", stringValue: "Trending posts on the instance \(baseAddress)"))
        channel.addChild(XMLElement(name: "link", stringValue: "\(baseAddress)/trending?trending=statuses&period=\(period)"))
        channel.addChild(XMLElement(name: "generator", stringValue: "Vernissage \(Constants.version)"))
        
        if let firstStatus = linkableStatuses.data.first, let lastDate = firstStatus.createdAt {
            channel.addChild(XMLElement(name: "lastBuildDate", stringValue: lastDate.toRFC822String()))
        }
                
        // Add status items.
        for status in linkableStatuses.data {
            let item = self.createItem(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            channel.addChild(item)
        }
        
        return xmlDocument.xmlString
    }
    
    func featured(on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 20)
        let linkableStatuses = try await timelineService.featuredStatuses(linkableParams: linkableParams, onlyLocal: false, on: context.db)
        
        // Create first node in the document.
        let rss = XMLElement(name: "rss")
        rss.setAttributesWith(["version":"2.0", "xmlns:webfeeds": "http://webfeeds.org/rss/1.0", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: rss)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
        
        // Add channel node to the rss node.
        let channel = XMLElement(name: "channel")
        rss.addChild(channel)
    
        // Add RSS header.
        channel.addChild(XMLElement(name: "title", stringValue: "Editor's choice timeline"))
        channel.addChild(XMLElement(name: "description", stringValue: "All featured public posts"))
        channel.addChild(XMLElement(name: "link", stringValue: "\(baseAddress)/editors?tab=statuses"))
        channel.addChild(XMLElement(name: "generator", stringValue: "Vernissage \(Constants.version)"))
        
        if let firstStatus = linkableStatuses.data.first, let lastDate = firstStatus.createdAt {
            channel.addChild(XMLElement(name: "lastBuildDate", stringValue: lastDate.toRFC822String()))
        }
                
        // Add status items.
        for status in linkableStatuses.data {
            let item = self.createItem(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            channel.addChild(item)
        }
        
        return xmlDocument.xmlString
    }
    
    func categories(category: Category, on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 20)
        let linkableStatuses = try await timelineService.category(linkableParams: linkableParams, categoryId: category.requireID(), onlyLocal: false, on: context.db)
        
        // Create first node in the document.
        let rss = XMLElement(name: "rss")
        rss.setAttributesWith(["version":"2.0", "xmlns:webfeeds": "http://webfeeds.org/rss/1.0", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: rss)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
        
        // Add channel node to the rss node.
        let channel = XMLElement(name: "channel")
        rss.addChild(channel)
    
        // Add RSS header.
        channel.addChild(XMLElement(name: "title", stringValue: category.name))
        channel.addChild(XMLElement(name: "description", stringValue: "Public post for category \(category.name)"))
        channel.addChild(XMLElement(name: "link", stringValue: "\(baseAddress)/categories/\(category.name)"))
        channel.addChild(XMLElement(name: "generator", stringValue: "Vernissage \(Constants.version)"))
        
        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            channel.addChild(XMLElement(name: "lastBuildDate", stringValue: lastDate.toRFC822String()))
        }
                
        // Add status items.
        for status in linkableStatuses {
            let item = self.createItem(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            channel.addChild(item)
        }
        
        return xmlDocument.xmlString
    }
    
    func hashtags(hashtag: String, on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 20)
        let linkableStatuses = try await timelineService.hashtags(linkableParams: linkableParams, hashtag: hashtag, onlyLocal: false, on: context.db)
        
        // Create first node in the document.
        let rss = XMLElement(name: "rss")
        rss.setAttributesWith(["version":"2.0", "xmlns:webfeeds": "http://webfeeds.org/rss/1.0", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: rss)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
        
        // Add channel node to the rss node.
        let channel = XMLElement(name: "channel")
        rss.addChild(channel)
    
        // Add RSS header.
        channel.addChild(XMLElement(name: "title", stringValue: "#\(hashtag)"))
        channel.addChild(XMLElement(name: "description", stringValue: "Public post for tag #\(hashtag)"))
        channel.addChild(XMLElement(name: "link", stringValue: "\(baseAddress)/tags/\(hashtag)"))
        channel.addChild(XMLElement(name: "generator", stringValue: "Vernissage \(Constants.version)"))
        
        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            channel.addChild(XMLElement(name: "lastBuildDate", stringValue: lastDate.toRFC822String()))
        }
                
        // Add status items.
        for status in linkableStatuses {
            let item = self.createItem(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            channel.addChild(item)
        }
        
        return xmlDocument.xmlString
    }
    
    private func createItem(status: Status, baseAddress: String, baseStoragePath: String) -> XMLElement {
        let item = XMLElement(name: "item")
        
        let guid = XMLElement(name: "guid", stringValue: status.activityPubUrl)
        guid.setAttributesWith(["isPermaLink": "true"])
        item.addChild(guid)

        
        if let pubDate = status.createdAt {
            item.addChild(XMLElement(name: "pubDate", stringValue: pubDate.toRFC822String()))
        }

        item.addChild(XMLElement(name: "link", stringValue: status.activityPubUrl))
        
        let itemDescription = status.isLocal ? status.note?.html(baseAddress: baseAddress, wrapInParagraph: true) : status.note
        item.addChild(XMLElement(name: "description", stringValue: itemDescription))
        
        if let attachment = status.attachments.first {
            let mediaContent = XMLElement(name: "media:content")
            
            let imageUrl = baseStoragePath.finished(with: "/") + attachment.originalFile.fileName
            mediaContent.setAttributesWith(["url": imageUrl, "type": "image/jpeg", "medium": "image"])
            
            if let description = attachment.description {
                let mediaDescription = XMLElement(name: "media:description", stringValue: description)
                mediaDescription.setAttributesWith(["type": "plain"])
                mediaContent.addChild(mediaDescription)
            }
            
            if status.contentWarning != nil && status.contentWarning?.isEmpty == false {
                let mediaDescription = XMLElement(name: "media:rating", stringValue: "adult")
                mediaDescription.setAttributesWith(["scheme": "urn:simple"])
                mediaContent.addChild(mediaDescription)
            } else {
                let mediaDescription = XMLElement(name: "media:rating", stringValue: "nonadult")
                mediaDescription.setAttributesWith(["scheme": "urn:simple"])
                mediaContent.addChild(mediaDescription)
            }
            
            item.addChild(mediaContent)
        }
        
        return item
    }
}
