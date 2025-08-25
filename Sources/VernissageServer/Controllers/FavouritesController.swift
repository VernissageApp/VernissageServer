//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension FavouritesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("favourites")
    
    func boot(routes: RoutesBuilder) throws {
        let timelinesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(FavouritesController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
                
        timelinesGroup
            .grouped(EventHandlerMiddleware(.favouritesList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
    }
}

/// Returns user's favourites statuses.
///
/// This is the controller that is responsible for managing the list of statuses
/// favourited by the user in the system.
///
/// > Important: Base controller URL: `/api/v1/favourites`.
struct FavouritesController {
        
    /// Exposing favourited list of statuses.
    ///
    /// This is an endpoint that returns a list of statuses which has been favourited by the user.
    ///
    /// Optional query params:
    /// - `onlyLocal` - `true` if list should contain only statuses added on local instance
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/favourites`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/favourites" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "data": [
    ///         {
    ///             "application": "Vernissage 1.0.0-alpha1",
    ///             "attachments": [
    ///                 {
    ///                     "blurhash": "U5C?r]~q00xu9F-;WBIU009F~q%M-;ayj[xu",
    ///                     "description": "Image",
    ///                     "id": "7333853122610388993",
    ///                     "license": {
    ///                         "code": "CC BY-SA",
    ///                         "id": "7310942225159069697",
    ///                         "name": "Attribution-ShareAlike",
    ///                         "url": "https://creativecommons.org/licenses/by-sa/4.0/"
    ///                     },
    ///                     "location": {
    ///                         "country": {
    ///                             "code": "PL",
    ///                             "id": "7257110629787191297",
    ///                             "name": "Poland"
    ///                         },
    ///                         "id": "7257110934739898369",
    ///                         "latitude": "51,1",
    ///                         "longitude": "17,03333",
    ///                         "name": "Wrocław"
    ///                     },
    ///                     "metadata": {
    ///                         "exif": {
    ///                             "createDate": "2022-10-20T14:24:51.037+02:00",
    ///                             "exposureTime": "1/500",
    ///                             "fNumber": "f/8",
    ///                             "focalLenIn35mmFilm": "85",
    ///                             "lens": "Zeiss Batis 1.8/85",
    ///                             "make": "SONY",
    ///                             "model": "ILCE-7M4",
    ///                             "photographicSensitivity": "100"
    ///                         }
    ///                     },
    ///                     "originalFile": {
    ///                         "aspect": 1.4998169168802635,
    ///                         "height": 2731,
    ///                         "url": "https://s3.eu-central-1.amazonaws.com/vernissage-test/088207bf34c749b0ab0eb95c98cc1dbf.jpg",
    ///                         "width": 4096
    ///                     },
    ///                     "smallFile": {
    ///                         "aspect": 1.5009380863039399,
    ///                         "height": 533,
    ///                         "url": "https://s3.eu-central-1.amazonaws.com/vernissage-test/4aff6ec34865483ab2e6b3b145826e46.jpg",
    ///                         "width": 800
    ///                     }
    ///                 }
    ///             ],
    ///             "bookmarked": false,
    ///             "commentsDisabled": false,
    ///             "contentWarning": "This photo contains nudity.",
    ///             "createdAt": "2024-02-10T06:16:39.852Z",
    ///             "favourited": false,
    ///             "favouritesCount": 0,
    ///             "featured": false,
    ///             "id": "7333853122610761729",
    ///             "isLocal": true,
    ///             "note": "Status text",
    ///             "noteHtml": "<p>Status text</p>",
    ///             "reblogged": false,
    ///             "reblogsCount": 0,
    ///             "repliesCount": 0,
    ///             "sensitive": true,
    ///             "tags": [],
    ///             "updatedAt": "2024-02-10T06:16:39.852Z",
    ///             "user": { ... },
    ///             "visibility": "public"
    ///         }
    ///     ],
    ///     "maxId": "7333853122610761729",
    ///     "minId": "7333853122610761729"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of linkable statuses.
    @Sendable
    func list(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let authorizationPayloadId = try request.requireUserId()
        let linkableParams = request.linkableParams()
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.favourites(for: authorizationPayloadId, linkableParams: linkableParams, on: request.db)
        
        let statusesService = request.application.services.statusesService
        let statusDtos = await statusesService.convertToDtos(statuses: statuses.data, on: request.executionContext)
        
        return LinkableResultDto(
            maxId: statuses.maxId,
            minId: statuses.minId,
            data: statusDtos
        )
    }
}
