//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension TrendingController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("trending")
    
    func boot(routes: RoutesBuilder) throws {
        let timelinesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(TrendingController.uri)
            .grouped(UserAuthenticator())
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.trendingStatuses))
            .grouped(CacheControlMiddleware(.noStore))
            .get("statuses", use: statuses)
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.trendingUsers))
            .grouped(CacheControlMiddleware(.noStore))
            .get("users", use: users)
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.trendingHashtags))
            .grouped(CacheControlMiddleware(.noStore))
            .get("hashtags", use: hashtags)
    }
}

///  Returns basic tranding timelines.
///
///  This controller is responsible for returning lists of statuses,
///  users or hashtags that are more popular during a specified time period.
///
/// > Important: Base controller URL: `/api/v1/trending`.
struct TrendingController {
    
    /// Exposing trending statuses.
    ///
    /// The endpoint returns a list of statuses that have received
    /// a significant number of likes by users during the set time period.
    ///
    /// Optional query params:
    /// - `period` - one of the following value: `daily`, `monthly`, `yearly`
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/trending/statuses`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/trending/statuses" \
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
    ///                         "url": "https://example.com/088207bf34c749b0ab0eb95c98cc1dbf.jpg",
    ///                         "width": 4096
    ///                     },
    ///                     "smallFile": {
    ///                         "aspect": 1.5009380863039399,
    ///                         "height": 533,
    ///                         "url": "https://example.com/4aff6ec34865483ab2e6b3b145826e46.jpg",
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
    func statuses(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let applicationSettings = request.application.settings.cached
        if request.userId == nil && applicationSettings?.showTrendingForAnonymous == false {
            throw ActionsForbiddenError.trendingForbidden
        }
        
        let period: TrendingStatusPeriodDto = request.query["period"] ?? .daily
        let linkableParams = request.linkableParams()
        
        let statusesService = request.application.services.statusesService
        let trendingService = request.application.services.trendingService
        let trending = try await trendingService.statuses(linkableParams: linkableParams, period: period.translate(), on: request.db)
        
        let statusDtos = await statusesService.convertToDtos(statuses: trending.data, on: request.executionContext)
        
        return LinkableResultDto(
            maxId: trending.maxId,
            minId: trending.minId,
            data: statusDtos
        )
    }
    
    /// Exposing trending users.
    ///
    /// The endpoint returns a list of users whose statuses havereceived
    /// a significant number of likes by users during the set time period.
    ///
    /// Optional query params:
    /// - `period` - one of the following value: `daily`, `monthly`, `yearly`
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/trending/users`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/trending/users" \
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
    ///             "account": "johndoe@example.com",
    ///             "activityPubProfile": "https://example.com/users/johndoe",
    ///             "avatarUrl": "https://example.com/09267580898c4d3abfc5871bbdb4483e.jpeg",
    ///             "bio": "<p>Landscape, nature and fine-art photographer</p>",
    ///             "bioHtml": "<p>Landscape, nature and fine-art photographer</p>",
    ///             "createdAt": "2023-08-16T15:13:08.607Z",
    ///             "fields": [],
    ///             "followersCount": 0,
    ///             "followingCount": 0,
    ///             "headerUrl": "https://example.com/700049efc6c04068a3634317e1f95e32.jpg",
    ///             "id": "7267938074834522113",
    ///             "isLocal": false,
    ///             "name": "John Doe",
    ///             "statusesCount": 0,
    ///             "updatedAt": "2024-02-09T05:12:23.479Z",
    ///             "userName": "johndoe@example.com"
    ///         },
    ///         {
    ///             "account": "lindadoe@example.com",
    ///             "activityPubProfile": "https://example.com/users/lindadoe",
    ///             "avatarUrl": "https://example.com/44debf8889d74b5a9be651f575a3651c.jpg",
    ///             "bio": "<p>Landscape, nature and street photographer</p>",
    ///             "bioHtml": "<p>Landscape, nature and street photographer</p>",
    ///             "createdAt": "2024-02-07T10:25:36.538Z",
    ///             "fields": [],
    ///             "followersCount": 0,
    ///             "followingCount": 0,
    ///             "id": "7332804261530576897",
    ///             "isLocal": false,
    ///             "name": "Linda Doe",
    ///             "statusesCount": 0,
    ///             "updatedAt": "2024-02-07T10:25:36.538Z",
    ///             "userName": "lindadoe@example.com"
    ///         }
    ///     ],
    ///     "maxId": "7333887748636160001",
    ///     "minId": "7333887748636174337"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of linkable users.
    @Sendable
    func users(request: Request) async throws -> LinkableResultDto<UserDto> {
        let applicationSettings = request.application.settings.cached
        if request.userId == nil && applicationSettings?.showTrendingForAnonymous == false {
            throw ActionsForbiddenError.trendingForbidden
        }
        
        let period: TrendingStatusPeriodDto = request.query["period"] ?? .daily
        let linkableParams = request.linkableParams()
        
        let trendingService = request.application.services.trendingService
        let trending = try await trendingService.users(linkableParams: linkableParams, period: period.translate(), on: request.db)
        
        let usersService = request.application.services.usersService
        let userDtos = await usersService.convertToDtos(users: trending.data, attachSensitive: false, on: request.executionContext)
                
        return LinkableResultDto(
            maxId: trending.maxId,
            minId: trending.minId,
            data: userDtos
        )
    }
    
    /// Exposing trending hashtags.
    ///
    /// Checkpoint returns a list of hashtags that are placed on statuses that
    /// have received a significant number of likes by users over a preset time period.
    ///
    /// Optional query params:
    /// - `period` - one of the following value: `daily`, `monthly`, `yearly`
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/trending/hashtags`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/trending/hashtags" \
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
    ///             "name": "analogvibes",
    ///             "url": "https://vernissage.photos/tags/analogvibes"
    ///         },
    ///         {
    ///             "name": "experimentalfilm",
    ///             "url": "https://vernissage.photos/tags/experimentalfilm"
    ///         },
    ///         {
    ///             "name": "fomapan100",
    ///             "url": "https://vernissage.photos/tags/fomapan100"
    ///         },
    ///         {
    ///             "name": "fotoperiodismo",
    ///             "url": "https://vernissage.photos/tags/fotoperiodismo"
    ///         },
    ///         {
    ///             "name": "mediumformatfilm",
    ///             "url": "https://vernissage.photos/tags/mediumformatfilm"
    ///         },
    ///         {
    ///             "name": "photography",
    ///             "url": "https://vernissage.photos/tags/photography"
    ///         },
    ///         {
    ///             "name": "portrait",
    ///             "url": "https://vernissage.photos/tags/portrait"
    ///         }
    ///     ],
    ///     "maxId": "7333887748636758017",
    ///     "minId": "7333887748636844033"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of linkable hashtags.
    @Sendable
    func hashtags(request: Request) async throws -> LinkableResultDto<HashtagDto> {
        let applicationSettings = request.application.settings.cached
        if request.userId == nil && applicationSettings?.showTrendingForAnonymous == false {
            throw ActionsForbiddenError.trendingForbidden
        }
        
        let period: TrendingStatusPeriodDto = request.query["period"] ?? .daily
        let linkableParams = request.linkableParams()
        
        let trendingService = request.application.services.trendingService
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""

        let trending = try await trendingService.hashtags(linkableParams: linkableParams, period: period.translate(), on: request.db)
        let hashtagDtos = await trending.data.asyncMap {
            HashtagDto(url: "\(baseAddress)/tags/\($0.hashtag)", name: $0.hashtag, amount: $0.amount)
        }
        
        return LinkableResultDto(
            maxId: trending.maxId,
            minId: trending.minId,
            data: hashtagDtos
        )
    }
}
