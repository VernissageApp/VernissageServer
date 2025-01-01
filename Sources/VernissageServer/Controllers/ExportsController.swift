//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension ExportsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("exports")
    
    func boot(routes: RoutesBuilder) throws {
        let exportsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(ExportsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())

        exportsGroup
            .grouped(EventHandlerMiddleware(.exportsFollowing))
            .grouped(CacheControlMiddleware(.noStore))
            .get("following", use: following)
        
        exportsGroup
            .grouped(EventHandlerMiddleware(.exportsBookmarks))
            .grouped(CacheControlMiddleware(.noStore))
            .get("bookmarks", use: bookmarks)
    }
}

/// Controller for exporting data from Vernissage.
///
/// These endpoints can be used to export data files from the Vernissage
/// with different information from the system.
///
/// > Important: Base controller URL: `/api/v1/exports`.
struct ExportsController {
    
    /// File with accounts that user follows.
    ///
    /// > Important: Endpoint URL: `/api/v1/exports/following`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/exports/following" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body (CSV file):**
    ///
    /// ```
    /// Account address,Show boosts,Notify on new posts,Languages
    /// account1@threads.net,true,false,
    /// account2@mas.to,true,false,
    /// account3@europa.eu,true,false,
    /// account4@vernissage.photos,true,false,
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: CSV file with follows accounts.
    ///
    @Sendable
    func following(request: Request) async throws -> Response {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        // Download accounts that user follows.
        let followsService = request.application.services.followsService
        let following = try await followsService.following(sourceId: authorizationPayloadId,
                                                           onlyApproved: true,
                                                           page: 1,
                                                           size: 100_000,
                                                           on: request.db)
        
        // Change list into the string.
        var stringResult = ""
        for follow in following.items {
            stringResult += "\(follow.account),false,false,en_US\n"
        }
        
        // Convert to data.
        guard let dataResult = stringResult.data(using: .ascii) else {
            throw ExportsError.cannotConvertToData
        }
        
        // Retur response.
        let response = Response()
        response.status = .ok
        response.headers.add(name: .contentType, value: "text/csv")
        response.body = Response.Body(data: dataResult)
        response.headers.contentDisposition = .init(.attachment, filename: "follows.csv")
        
        return response
    }
    
    /// File with user's bookmarks.
    ///
    /// > Important: Endpoint URL: `/api/v1/exports/bookmarks`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/exports/bookmarks" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body (CSV file):**
    ///
    /// ```
    /// https://server1.social/users/johndoe/statuses/113588442880717539
    /// https://server2.io/users/mariadoe/statuses/113391222166042896
    /// https://server3.com/users/annadoe/statuses/113364465199113486
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: CSV file with bookmarks.
    ///
    @Sendable
    func bookmarks(request: Request) async throws -> Response {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        // Download accounts that user follows.
        let bookmarks = try await StatusBookmark.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .with(\.$status)
            .sort(\.$createdAt, .descending)
            .all()
        
        let bookmarkActivityPubIds = bookmarks.map { $0.status.activityPubId }

        // Change list into the string.
        var stringResult = ""
        for bookmarkActivityPubId in bookmarkActivityPubIds {
            stringResult += "\(bookmarkActivityPubId)\n"
        }
        
        // Convert to data.
        guard let dataResult = stringResult.data(using: .ascii) else {
            throw ExportsError.cannotConvertToData
        }
        
        // Retur response.
        let response = Response()
        response.status = .ok
        response.headers.add(name: .contentType, value: "text/csv")
        response.body = Response.Body(data: dataResult)
        response.headers.contentDisposition = .init(.attachment, filename: "bookmarks.csv")
        
        return response
    }
}
