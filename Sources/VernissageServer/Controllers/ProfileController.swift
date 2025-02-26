//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Vapor
import Fluent
import ActivityPubKit

extension ProfileController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        // Support for: https://example.com/@johndoe
        routes
            .grouped(UserAuthenticator())
            .grouped(EventHandlerMiddleware(.usersRead))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":name", use: read)
        
        // Support for RSS feed: https://example.com/@johndoe/rss
        routes
            .grouped(UserAuthenticator())
            .grouped(EventHandlerMiddleware(.usersRead))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":name", "rss", use: rss)
    }
}

/// Controller for exposing user profile.
///
/// The controller is created specificaly for supporting downloading
/// user accounts during search from other fediverse platforms.
///
/// > Important: Base controller URL: `/:username`.
struct ProfileController {
    let activityPubActorsController = ActivityPubActorsController()
    
    /// Returns user ActivityPub profile.
    ///
    /// Endpoint for download Activity Pub actor's data. One of the property is public key which should be used to validate requests
    /// done (and signed by private key) by the user in all Activity Pub protocol methods.
    ///
    /// > Important: Endpoint URL: `/api/v1/actors`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/actors/johndoe" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "@context": [
    ///         "https://w3id.org/security/v1",
    ///         "https://www.w3.org/ns/activitystreams"
    ///     ],
    ///     "attachment": [
    ///         {
    ///             "name": "MASTODON",
    ///             "type": "PropertyValue",
    ///             "value": "https://mastodon.social/@johndoe"
    ///         },
    ///         {
    ///             "name": "GITHUB",
    ///             "type": "PropertyValue",
    ///             "value": "https://github.com/johndoe"
    ///         }
    ///     ],
    ///     "endpoints": {
    ///         "sharedInbox": "https://example.com/shared/inbox"
    ///     },
    ///     "followers": "https://example.com/actors/johndoe/followers",
    ///     "following": "https://example.com/actors/johndoe/following",
    ///     "icon": {
    ///         "mediaType": "image/jpeg",
    ///         "type": "Image",
    ///         "url": "https://s3.eu-central-1.amazonaws.com/instance/039ebf33d1664d5d849574d0e7191354.jpg"
    ///     },
    ///     "id": "https://example.com/actors/johndoe",
    ///     "image": {
    ///         "mediaType": "image/jpeg",
    ///         "type": "Image",
    ///         "url": "https://s3.eu-central-1.amazonaws.com/instance/2ef4a0f69d0e410ba002df2212e2b63c.jpg"
    ///     },
    ///     "inbox": "https://example.com/actors/johndoe/inbox",
    ///     "manuallyApprovesFollowers": false,
    ///     "name": "John Doe",
    ///     "outbox": "https://example.com/actors/johndoe/outbox",
    ///     "preferredUsername": "johndoe",
    ///     "publicKey": {
    ///         "id": "https://example.com/actors/johndoe#main-key",
    ///         "owner": "https://example.com/actors/johndoe",
    ///         "publicKeyPem": "-----BEGIN PUBLIC KEY-----\nM0Q....AB\n-----END PUBLIC KEY-----"
    ///     },
    ///     "summary": "#iOS/#dotNET developer, #Apple  fanboy, 📷 aspiring photographer",
    ///     "tag": [
    ///         {
    ///             "href": "https://example.com/tags/Apple",
    ///             "name": "Apple",
    ///             "type": "Hashtag"
    ///         },
    ///         {
    ///             "href": "https://example.com/tags/dotNET",
    ///             "name": "dotNET",
    ///             "type": "Hashtag"
    ///         },
    ///         {
    ///             "href": "https://example.com/tags/iOS",
    ///             "name": "iOS",
    ///             "type": "Hashtag"
    ///         }
    ///     ],
    ///     "type": "Person",
    ///     "url": "https://example.com/@johndoe",
    ///     "alsoKnownAs": [
    ///         "https://test.social/users/marcin"
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about user information.
    @Sendable
    func read(request: Request) async throws -> Response {
        return try await activityPubActorsController.read(request: request)
    }
    
    @Sendable
    func rss(request: Request) async throws -> Response {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }

        let usersService = request.application.services.usersService
        let clearedUserName = userName.deletingPrefix("@")
        let userFromDb = try await usersService.get(userName: clearedUserName, on: request.db)
        
        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }
        
        let appplicationSettings = request.application.settings.cached
        let storageService = request.application.services.storageService

        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let baseStoragePath = storageService.getBaseStoragePath(on: request.executionContext)
        
        let linkableParams = LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 20)
        let linkableStatuses = try await usersService.publicStatuses(for: user.requireID(), linkableParams: linkableParams, on: request)
        
        let rss = XMLElement(name: "rss")
        rss.setAttributesWith(["version":"2.0", "xmlns:webfeeds": "http://webfeeds.org/rss/1.0", "xmlns:media": "http://search.yahoo.com/mrss/"])
        let xml = XMLDocument(rootElement: rss)
        
        let channel = XMLElement(name: "channel")
    
        // Add RSS header.
        channel.addChild(XMLElement(name: "title", stringValue: user.name ?? user.userName))
        channel.addChild(XMLElement(name: "description", stringValue: "Public posts from @\(user.account)"))
        channel.addChild(XMLElement(name: "link", stringValue: user.url ?? "\(baseAddress)/@\(user.userName)"))
        channel.addChild(XMLElement(name: "generator", stringValue: "Vernissage \(Constants.version)"))
        
        if let thumbnail = appplicationSettings?.webThumbnail, !thumbnail.isEmpty {
            channel.addChild(XMLElement(name: "webfeeds:icon", stringValue: thumbnail))
        }
        
        if let firstStatus = linkableStatuses.data.first, let lastDate = firstStatus.createdAt {
            channel.addChild(XMLElement(name: "lastBuildDate", stringValue: lastDate.toISO8601String()))
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
        }
        
        // Add status items.
        for status in linkableStatuses.data {
            let item = XMLElement(name: "item")
            
            let guid = XMLElement(name: "guid", stringValue: status.activityPubUrl)
            guid.setAttributesWith(["isPermaLink": "true"])
            item.addChild(guid)

            
            if let pubDate = status.createdAt {
                item.addChild(XMLElement(name: "pubDate", stringValue: pubDate.toISO8601String()))
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

            channel.addChild(item)
        }
        
        rss.addChild(channel)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentType, value: "application/rss+xml; charset=utf-8")
        
        return try await xml.xmlString.encodeResponse(status: .ok, headers: headers, for: request)
    }
}
