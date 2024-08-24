//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

extension WellKnownController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant(".well-known")
    
    func boot(routes: RoutesBuilder) throws {
        let wellKnownGroup = routes.grouped(WellKnownController.uri)
        
        wellKnownGroup
            .grouped(EventHandlerMiddleware(.webfinger))
            .get("webfinger", use: webfinger)

        wellKnownGroup
            .grouped(EventHandlerMiddleware(.nodeinfo))
            .get("nodeinfo", use: nodeinfo)

        wellKnownGroup
            .grouped(EventHandlerMiddleware(.hostMeta))
            .get("host-meta", use: hostMeta)
    }
}

/// Controller which exposes Well-Known functionality (webfinger, nodeinfo, host-meta).
final class WellKnownController {
        
    /// Exposing webfinger data.
    ///
    /// WebFinger is used to discover information about people or other entities on the Internet that are identified
    /// by a URI using standard Hypertext Transfer Protocol (HTTP) methods over a secure transport. A WebFinger
    /// resource returns a JavaScript Object Notation (JSON) object describing the entity that is queried.
    /// The JSON object is referred to as the JSON Resource Descriptor (JRD).
    /// More info: [https://webfinger.net](https://webfinger.net).
    ///
    /// > Important: Endpoint URL: `/.well-known/webfinger?resource=acct:userName`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/.well-known/webfinger?resource=acct:johndoe@example.com" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "subject": "acct:johndoe@example.com",
    ///     "aliases": [
    ///         "https://example.com/@johndoe",
    ///         "https://example.com/actors/johndoe"
    ///     ],
    ///     "links": [
    ///         {
    ///             "rel": "http://webfinger.net/rel/profile-page",
    ///             "type": "text/html",
    ///             "href": "https://example.com/@mczachurski"
    ///         },
    ///         {
    ///             "rel": "self",
    ///             "type": "application/activity+json",
    ///             "href": "https://example.com/actors/johndoe"
    ///         }
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Webfinger information.
    func webfinger(request: Request) async throws -> Response {
        let resource: String? = request.query["resource"]
        
        guard let resource else {
            throw Abort(.badRequest)
        }
        
        let account = resource.deletingPrefix("acct:")

        if self.isApplication(account: account, on: request) {
            let applicationResponse = try await self.createApplicationResponse(on: request)
            return applicationResponse
        }

        let userResponse = try await self.createUserResponse(for: account, on: request)
        return userResponse
    }
    
    /// Exposing nodeinfo data.
    ///
    /// NodeInfo is an effort to create a standardized way of exposing metadata about a server running one of the distributed social networks.
    /// The two key goals are being able to get better insights into the user base of distributed social networking and the ability to build tools
    /// that allow users to choose the best-fitting software and server for their needs.
    /// More info: [https://github.com/jhass/nodeinfo](https://github.com/jhass/nodeinfo).
    ///
    /// > Important: Endpoint URL: `/.well-known/nodeinfo`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/.well-known/nodeinfo" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "links": [
    ///         {
    ///             "rel": "http://nodeinfo.diaspora.software/ns/schema/2.0",
    ///             "href": "https://example.com/nodeinfo/2.0"
    ///         }
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: NodeInfo information.
    func nodeinfo(request: Request) async throws -> NodeInfoLinkDto {
        let appplicationSettings = request.application.settings.cached
        let baseAddress = appplicationSettings?.baseAddress ?? ""

        return NodeInfoLinkDto(rel: "http://nodeinfo.diaspora.software/ns/schema/2.0",
                               href: "\(baseAddress)/api/v1/nodeinfo/2.0")
    }
    
    /// Exposing host metadata.
    ///
    /// Web-based protocols often require the discovery of host policy or metadata, where "host" is not a single resource
    /// but the entity controlling the collection of resources identified by Uniform Resource Identifiers (URIs) with a common
    /// URI host [RFC3986](https://www.rfc-editor.org/rfc/rfc3986), which can be served by one or more servers.
    /// More info: [RFC6415](https://www.rfc-editor.org/rfc/rfc6415).
    ///
    /// > Important: Endpoint URL: `/.well-known/host-meta`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/.well-known/host-meta" -X GET
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
    ///     <Link rel="lrdd" template="https://example.com/.well-known/webfinger?resource={uri}"/>
    /// </XRD>
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Host metadata information.
    func hostMeta(request: Request) async throws -> Response {
        let appplicationSettings = request.application.settings.cached
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        
        let hostMetaBody =
"""
<?xml version="1.0" encoding="UTF-8"?>
<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
    <Link rel="lrdd" template="\(baseAddress)/.well-known/webfinger?resource={uri}"/>
</XRD>
"""

        var headers = HTTPHeaders()
        headers.contentType = Constants.xrdXmlContentType
        
        return Response(headers: headers, body: Response.Body(string: hostMetaBody))
    }
    
    private func isApplication(account: String, on request: Request) -> Bool {
        let applicationSettings = request.application.settings.cached
        guard let domain = applicationSettings?.domain else {
            return false
        }
        
        if account == "\(domain)@\(domain)" {
            return true
        }
        
        if account == "\(domain)%40\(domain)" {
            return true
        }
        
        return false
    }
    
    private func createUserResponse(for account: String, on request: Request) async throws -> Response {
        let usersService = request.application.services.usersService
        let userFromDb = try await usersService.get(on: request.db, account: account)
        
        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        let applicationSettings = request.application.settings.cached
        let baseAddress = applicationSettings?.baseAddress ?? ""

        let webfingetDto = WebfingerDto(subject: "acct:\(user.account)",
                                        aliases: ["\(baseAddress)/@\(user.userName)", "\(baseAddress)/actors/\(user.userName)"],
                                        links: [
                                            WebfingerLinkDto(rel: "self",
                                                             type: "application/activity+json",
                                                             href: "\(baseAddress)/actors/\(user.userName)"),
                                            WebfingerLinkDto(rel: "http://webfinger.net/rel/profile-page",
                                                             type: "text/html",
                                                             href: "\(baseAddress)/@\(user.userName)")
                                        ])
        
        let response = try await webfingetDto.encodeResponse(for: request)
        response.headers.contentType = Constants.jrdJsonContentType
        
        return response
    }
    
    private func createApplicationResponse(on request: Request) async throws -> Response {
        let usersService = request.application.services.usersService
        let userFromDb = try await usersService.getDefaultSystemUser(on: request.db)
        
        guard let _ = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }

        let applicationSettings = request.application.settings.cached
        let baseAddress = applicationSettings?.baseAddress ?? ""
        let domain = applicationSettings?.domain ?? ""

        let webfingetDto = WebfingerDto(subject: "acct:\(domain)@\(domain)",
                                        aliases: ["\(baseAddress)/actor"],
                                        links: [
                                            WebfingerLinkDto(rel: "self",
                                                             type: "application/activity+json",
                                                             href: "\(baseAddress)/actor"),
                                            WebfingerLinkDto(rel: "http://webfinger.net/rel/profile-page",
                                                             type: "text/html",
                                                             href: "\(baseAddress)/support")
                                        ])
        
        let response = try await webfingetDto.encodeResponse(for: request)
        response.headers.contentType = Constants.jrdJsonContentType
        
        return response
    }
}
