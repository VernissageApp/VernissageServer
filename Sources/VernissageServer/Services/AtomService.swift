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
    func feed(for user: User, on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let usersService = context.application.services.usersService

        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 40)
        let linkableStatuses = try await usersService.publicStatuses(for: user.requireID(), linkableParams: linkableParams, on: context)
        
        // Create first node in the document.
        let feed = XMLElement(name: "feed")
        feed.setAttributesWith(["xmlns":"http://www.w3.org/2005/Atom", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: feed)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
    
        // Add feed header.
        feed.addChild(XMLElement(name: "title", stringValue: user.name ?? user.userName))
        feed.addChild(XMLElement(name: "subtitle", stringValue: "Public posts from @\(user.account)"))
        feed.addChild(XMLElement(name: "link", stringValue: user.url ?? "\(baseAddress)/@\(user.userName)"))
        
        let generator = XMLElement(name: "generator", stringValue: "Vernissage")
        generator.setAttributesWith(["version": Constants.version])
        feed.addChild(generator)
        
        if let firstStatus = linkableStatuses.data.first, let lastDate = firstStatus.createdAt {
            feed.addChild(XMLElement(name: "updated", stringValue: lastDate.toISO8601String()))
        }
        
        // Author element.
        let author = XMLElement(name: "author")
        author.addChild(XMLElement(name: "name", stringValue: user.name ?? user.userName))
        author.addChild(XMLElement(name: "uri", stringValue: user.url ?? "\(baseAddress)/@\(user.userName)"))
        feed.addChild(author)
        
        // User icon.
        if let avatarUrl = UserDto.getAvatarUrl(user: user, baseStoragePath: baseStoragePath) {
            feed.addChild(XMLElement(name: "icon", stringValue: avatarUrl))
            feed.addChild(XMLElement(name: "logo", stringValue: avatarUrl))
        }
        
        // Add status items.
        for status in linkableStatuses.data {
            let entry = self.createEntry(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            feed.addChild(entry)
        }
        
        return xmlDocument.xmlString
    }
    
    func local(on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 40)
        let linkableStatuses = try await timelineService.public(linkableParams: linkableParams, onlyLocal: true, on: context.db)
        
        // Create first node in the document.
        let feed = XMLElement(name: "feed")
        feed.setAttributesWith(["xmlns":"http://www.w3.org/2005/Atom", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: feed)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
    
        // Add feed header.
        feed.addChild(XMLElement(name: "title", stringValue: "Local timeline"))
        feed.addChild(XMLElement(name: "subtitle", stringValue: "Public posts from the instance \(baseAddress)"))
        feed.addChild(XMLElement(name: "link", stringValue: "\(baseAddress)/home?t=local"))
        
        let generator = XMLElement(name: "generator", stringValue: "Vernissage")
        generator.setAttributesWith(["version": Constants.version])
        feed.addChild(generator)
        
        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            feed.addChild(XMLElement(name: "updated", stringValue: lastDate.toISO8601String()))
        }
        
        // Add status items.
        for status in linkableStatuses {
            let entry = self.createEntry(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            feed.addChild(entry)
        }
        
        return xmlDocument.xmlString
    }
    
    func global(on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 40)
        let linkableStatuses = try await timelineService.public(linkableParams: linkableParams, onlyLocal: false, on: context.db)
        
        // Create first node in the document.
        let feed = XMLElement(name: "feed")
        feed.setAttributesWith(["xmlns":"http://www.w3.org/2005/Atom", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: feed)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
    
        // Add feed header.
        feed.addChild(XMLElement(name: "title", stringValue: "Global timeline"))
        feed.addChild(XMLElement(name: "subtitle", stringValue: "All public posts"))
        feed.addChild(XMLElement(name: "link", stringValue: "\(baseAddress)/home?t=global"))
        
        let generator = XMLElement(name: "generator", stringValue: "Vernissage")
        generator.setAttributesWith(["version": Constants.version])
        feed.addChild(generator)
        
        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            feed.addChild(XMLElement(name: "updated", stringValue: lastDate.toISO8601String()))
        }
        
        // Add status items.
        for status in linkableStatuses {
            let entry = self.createEntry(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            feed.addChild(entry)
        }
        
        return xmlDocument.xmlString
    }
    
    func trending(period: TrendingPeriod, on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let trendingService = context.application.services.trendingService

        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 40)
        let linkableStatuses = try await trendingService.statuses(linkableParams: linkableParams, period: period, on: context.db)
        
        // Create first node in the document.
        let feed = XMLElement(name: "feed")
        feed.setAttributesWith(["xmlns":"http://www.w3.org/2005/Atom", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: feed)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
    
        // Add feed header.
        feed.addChild(XMLElement(name: "title", stringValue: "Trending posts (\(period))"))
        feed.addChild(XMLElement(name: "subtitle", stringValue: "Trending posts on the instance \(baseAddress)"))
        feed.addChild(XMLElement(name: "link", stringValue: "\(baseAddress)/trending?trending=statuses&period=\(period)"))
        
        let generator = XMLElement(name: "generator", stringValue: "Vernissage")
        generator.setAttributesWith(["version": Constants.version])
        feed.addChild(generator)
        
        if let firstStatus = linkableStatuses.data.first, let lastDate = firstStatus.createdAt {
            feed.addChild(XMLElement(name: "updated", stringValue: lastDate.toISO8601String()))
        }
                
        // Add status items.
        for status in linkableStatuses.data {
            let entry = self.createEntry(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            feed.addChild(entry)
        }
        
        return xmlDocument.xmlString
    }
    
    func featured(on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 40)
        let linkableStatuses = try await timelineService.featuredStatuses(linkableParams: linkableParams, onlyLocal: false, on: context.db)
                
        // Create first node in the document.
        let feed = XMLElement(name: "feed")
        feed.setAttributesWith(["xmlns":"http://www.w3.org/2005/Atom", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: feed)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
    
        // Add feed header.
        feed.addChild(XMLElement(name: "title", stringValue: "Editor's choice timeline"))
        feed.addChild(XMLElement(name: "subtitle", stringValue: "All featured public posts"))
        feed.addChild(XMLElement(name: "link", stringValue: "\(baseAddress)/editors?tab=statuses"))
        
        let generator = XMLElement(name: "generator", stringValue: "Vernissage")
        generator.setAttributesWith(["version": Constants.version])
        feed.addChild(generator)
        
        if let firstStatus = linkableStatuses.data.first, let lastDate = firstStatus.createdAt {
            feed.addChild(XMLElement(name: "updated", stringValue: lastDate.toISO8601String()))
        }
        
        // Add status items.
        for status in linkableStatuses.data {
            let entry = self.createEntry(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            feed.addChild(entry)
        }
        
        return xmlDocument.xmlString
    }
    
    func categories(category: Category, on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 40)
        let linkableStatuses = try await timelineService.category(linkableParams: linkableParams, categoryId: category.requireID(), onlyLocal: false, on: context.db)
        
        // Create first node in the document.
        let feed = XMLElement(name: "feed")
        feed.setAttributesWith(["xmlns":"http://www.w3.org/2005/Atom", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: feed)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
    
        // Add feed header.
        feed.addChild(XMLElement(name: "title", stringValue: category.name))
        feed.addChild(XMLElement(name: "subtitle", stringValue: "Public post for category \(category.name)"))
        feed.addChild(XMLElement(name: "link", stringValue: "\(baseAddress)/categories/\(category.name)"))
        
        let generator = XMLElement(name: "generator", stringValue: "Vernissage")
        generator.setAttributesWith(["version": Constants.version])
        feed.addChild(generator)
        
        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            feed.addChild(XMLElement(name: "updated", stringValue: lastDate.toISO8601String()))
        }
        
        // Add status items.
        for status in linkableStatuses {
            let entry = self.createEntry(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            feed.addChild(entry)
        }
        
        return xmlDocument.xmlString
    }
    
    func hashtags(hashtag: String, on context: ExecutionContext) async throws -> String {
        let appplicationSettings = context.application.settings.cached
        let storageService = context.application.services.storageService
        let timelineService = context.application.services.timelineService

        let baseAddress = appplicationSettings?.baseAddress.deletingSuffix("/") ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: context)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 40)
        let linkableStatuses = try await timelineService.hashtags(linkableParams: linkableParams, hashtag: hashtag, onlyLocal: false, on: context.db)
        
        // Create first node in the document.
        let feed = XMLElement(name: "feed")
        feed.setAttributesWith(["xmlns":"http://www.w3.org/2005/Atom", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xmlDocument = XMLDocument(rootElement: feed)
        xmlDocument.version = "1.0"
        xmlDocument.characterEncoding = "UTF-8"
    
        // Add feed header.
        feed.addChild(XMLElement(name: "title", stringValue: "#\(hashtag)"))
        feed.addChild(XMLElement(name: "subtitle", stringValue: "Public post for tag #\(hashtag)"))
        feed.addChild(XMLElement(name: "link", stringValue: "\(baseAddress)/tags/\(hashtag)"))
        
        let generator = XMLElement(name: "generator", stringValue: "Vernissage")
        generator.setAttributesWith(["version": Constants.version])
        feed.addChild(generator)
        
        if let firstStatus = linkableStatuses.first, let lastDate = firstStatus.createdAt {
            feed.addChild(XMLElement(name: "updated", stringValue: lastDate.toISO8601String()))
        }
        
        // Add status items.
        for status in linkableStatuses {
            let entry = self.createEntry(status: status, baseAddress: baseAddress, baseStoragePath: baseStoragePath)
            feed.addChild(entry)
        }
        
        return xmlDocument.xmlString
    }
    
    private func createEntry(status: Status, baseAddress: String, baseStoragePath: String) -> XMLElement {
        let entry = XMLElement(name: "entry")

        entry.addChild(XMLElement(name: "id", stringValue: status.activityPubUrl))
        entry.addChild(XMLElement(name: "title", stringValue: "\(status.user.name ?? status.user.userName) photo"))
        entry.addChild(XMLElement(name: "link", stringValue: status.activityPubUrl))
        
        if let pubDate = status.createdAt {
            entry.addChild(XMLElement(name: "updated", stringValue: pubDate.toISO8601String()))
            entry.addChild(XMLElement(name: "published", stringValue: pubDate.toISO8601String()))
        }
        
        // Author element.
        let author = XMLElement(name: "author")
        author.addChild(XMLElement(name: "name", stringValue: status.user.name ?? status.user.userName))
        author.addChild(XMLElement(name: "uri", stringValue: status.user.url ?? "\(baseAddress)/@\(status.user.userName)"))
        entry.addChild(author)
        
        let entryContent = status.isLocal ? status.note?.html(baseAddress: baseAddress, wrapInParagraph: true) : status.note
        let content = XMLElement(name: "content", stringValue: entryContent)
        content.setAttributesWith(["type": "html"])
        entry.addChild(content)
        
        // Add image element.
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
                        
            if let license = attachment.license?.name {
                entry.addChild(XMLElement(name: "rights", stringValue: license))
            }
            
            entry.addChild(mediaContent)
        }
        
        // Add categories elements.
        for tag in status.hashtags {
            let category = XMLElement(name: "category")
            category.setAttributesWith(["term": tag.hashtag])
            entry.addChild(category)
        }
        
        return entry
    }
}
