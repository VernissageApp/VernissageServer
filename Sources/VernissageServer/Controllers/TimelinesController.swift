//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension TimelinesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("timelines")
    
    func boot(routes: RoutesBuilder) throws {
        let timelinesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(TimelinesController.uri)
            .grouped(UserAuthenticator())
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.timelinesPublic))
            .grouped(CacheControlMiddleware(.noStore))
            .get("public", use: list)
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.timelinesCategories))
            .grouped(CacheControlMiddleware(.noStore))
            .get("category", ":category", use: category)
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.timelinesHashtags))
            .grouped(CacheControlMiddleware(.noStore))
            .get("hashtag", ":hashtag", use: hashtag)

        timelinesGroup
            .grouped(EventHandlerMiddleware(.timelinesFeaturedStatuses))
            .grouped(CacheControlMiddleware(.noStore))
            .get("featured-statuses", use: featuredStatuses)
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.timelinesFeaturedUsers))
            .grouped(CacheControlMiddleware(.noStore))
            .get("featured-users", use: featuredUsers)
        
        timelinesGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.timelinesPublic))
            .grouped(CacheControlMiddleware(.noStore))
            .get("home", use: home)
    }
}

/// Returns user's timelines.
///
/// This is the main controller for displaying status lists to users.
/// The statuses in the lists are sorted from newest to oldest,
/// there is no algorithm additionally affecting the lists and no ads.
///
/// > Important: Base controller URL: `/api/v1/timelines`.
struct TimelinesController {
        
    /// Exposing timeline.
    ///
    /// This is an endpoint that returns a list of statuses that can be
    /// displayed to all users. You can set in the settings if the timeline should be visible for anonymous users.
    ///
    /// Optional query params:
    /// - `onlyLocal` - `true` if list should contain only statuses added on local instance
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/timelines/public`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/timelines/public" \
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
    ///
    /// - Throws: `ActionsForbiddenError.localTimelineForbidden` if access to timeline is forbidden.
    @Sendable
    func list(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let applicationSettings = request.application.settings.cached
        if request.userId == nil && applicationSettings?.showLocalTimelineForAnonymous == false {
            throw ActionsForbiddenError.localTimelineForbidden
        }
        
        let onlyLocal: Bool = request.query["onlyLocal"] ?? false
        let linkableParams = request.linkableParams()
                
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.public(linkableParams: linkableParams, onlyLocal: onlyLocal, on: request.db)
        
        let statusesService = request.application.services.statusesService
        let statusDtos = await statusesService.convertToDtos(statuses: statuses, on: request.executionContext)
        
        return LinkableResultDto(
            maxId: statuses.last?.stringId(),
            minId: statuses.first?.stringId(),
            data: statusDtos
        )
    }
    
    /// Exposing category timeline.
    ///
    /// This is an endpoint that returns a list of statuses that are assigned to a category.
    /// You can set in the settings if the timeline should be visible for anonymous users.
    ///
    /// Optional query params:
    /// - `onlyLocal` - `true` if list should contain only statuses added on local instance
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/timelines/category/:name`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/timelines/category/Street" \
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
    ///             "category": {
    ///                 "id": "7302429509785630721",
    ///                 "name": "Street"
    ///             },
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
    ///
    /// - Throws: `ActionsForbiddenError.categoriesForbidden` if access to timeline is forbidden.
    /// - Throws: `TimelineError.categoryNameIsRequired` if category is not specified.
    /// - Throws: `EntityNotFoundError.categoryNotFound` if category not exists.
    @Sendable
    func category(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let applicationSettings = request.application.settings.cached
        if request.userId == nil && applicationSettings?.showCategoriesForAnonymous == false {
            throw ActionsForbiddenError.categoriesForbidden
        }
        
        let onlyLocal: Bool = request.query["onlyLocal"] ?? false
        let linkableParams = request.linkableParams()
        
        guard let categoryName = request.parameters.get("category") else {
            throw TimelineError.categoryNameIsRequired
        }
        
        guard let category = try await Category.query(on: request.db)
            .filter(\.$nameNormalized == categoryName.uppercased())
            .first() else {
            throw EntityNotFoundError.categoryNotFound
        }
        
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.category(linkableParams: linkableParams, categoryId: category.requireID(), onlyLocal: onlyLocal, on: request.db)
        
        let statusesService = request.application.services.statusesService
        let statusDtos = await statusesService.convertToDtos(statuses: statuses, on: request.executionContext)
        
        return LinkableResultDto(
            maxId: statuses.last?.stringId(),
            minId: statuses.first?.stringId(),
            data: statusDtos
        )
    }
    
    /// Exposing hashtag timeline. You can set in the settings if the timeline should be visible for anonymous users.
    ///
    /// This is an endpoint that returns a list of statuses that are assigned to a given hashtag.
    ///
    /// Optional query params:
    /// - `onlyLocal` - `true` if list should contain only statuses added on local instance
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/timelines/hashtag/:name`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/timelines/hashtag/street" \
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
    ///             "category": {
    ///                 "id": "7302429509785630721",
    ///                 "name": "Street"
    ///             },
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
    ///             "tags": [
    ///                 {
    ///                     "name": "street",
    ///                     "url": "https://vernissage.photos/tags/street"
    ///                 }
    ///             ],
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
    ///
    /// - Throws: `ActionsForbiddenError.hashtagsForbidden` if access to timeline is forbidden.
    /// - Throws: `TimelineError.hashtagNameIsRequired` if hashtag is not specified.
    @Sendable
    func hashtag(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let applicationSettings = request.application.settings.cached
        if request.userId == nil && applicationSettings?.showHashtagsForAnonymous == false {
            throw ActionsForbiddenError.hashtagsForbidden
        }

        
        let onlyLocal: Bool = request.query["onlyLocal"] ?? false
        let linkableParams = request.linkableParams()
        
        guard let hashtag = request.parameters.get("hashtag") else {
            throw TimelineError.hashtagNameIsRequired
        }
        
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.hashtags(linkableParams: linkableParams, hashtag: hashtag, onlyLocal: onlyLocal, on: request.db)
        
        let statusesService = request.application.services.statusesService
        let statusDtos = await statusesService.convertToDtos(statuses: statuses, on: request.executionContext)
        
        return LinkableResultDto(
            maxId: statuses.last?.stringId(),
            minId: statuses.first?.stringId(),
            data: statusDtos
        )
    }
    
    /// Exposing featured timeline. You can set in the settings if the timeline should be visible for anonymous users.
    ///
    /// This is an endpoint that returns a list of statuses that have been featured by moderators/administrators.
    ///
    /// Optional query params:
    /// - `onlyLocal` - `true` if list should contain only statuses added on local instance
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/timelines/featured-statuses`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/timelines/featured-statuses" \
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
    ///             "category": {
    ///                 "id": "7302429509785630721",
    ///                 "name": "Street"
    ///             },
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
    ///
    /// - Throws: `ActionsForbiddenError.editorsStatusesChoiceForbidden` if access to timeline is forbidden.
    @Sendable
    func featuredStatuses(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let applicationSettings = request.application.settings.cached
        if request.userId == nil && applicationSettings?.showEditorsChoiceForAnonymous == false {
            throw ActionsForbiddenError.editorsStatusesChoiceForbidden
        }
        
        let onlyLocal: Bool = request.query["onlyLocal"] ?? false
        let linkableParams = request.linkableParams()
                
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.featuredStatuses(linkableParams: linkableParams, onlyLocal: onlyLocal, on: request.db)
        
        let statusesService = request.application.services.statusesService
        let statusDtos = await statusesService.convertToDtos(statuses: statuses.data, on: request.executionContext)
        
        return LinkableResultDto(
            maxId: statuses.maxId,
            minId: statuses.minId,
            data: statusDtos
        )
    }
    
    /// Exposing featured users. You can set in the settings if the timeline should be visible for anonymous users.
    ///
    /// This is an endpoint that returns a list of users that have been featured by moderators/administrators.
    ///
    /// Optional query params:
    /// - `onlyLocal` - `true` if list should contain only users added on local instance
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/timelines/featured-users`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/timelines/featured-users" \
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
    ///     "maxId": "7333853122610761729",
    ///     "minId": "7333853122610761729"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of linkable users.
    ///
    /// - Throws: `ActionsForbiddenError.editorsUsersChoiceForbidden` if access to timeline is forbidden.
    @Sendable
    func featuredUsers(request: Request) async throws -> LinkableResultDto<UserDto> {
        let applicationSettings = request.application.settings.cached
        if request.userId == nil && applicationSettings?.showEditorsUsersChoiceForAnonymous == false {
            throw ActionsForbiddenError.editorsUsersChoiceForbidden
        }
        
        let onlyLocal: Bool = request.query["onlyLocal"] ?? false
        let linkableParams = request.linkableParams()
                
        let timelineService = request.application.services.timelineService
        let users = try await timelineService.featuredUsers(linkableParams: linkableParams, onlyLocal: onlyLocal, on: request.db)
                
        let usersService = request.application.services.usersService
        let userDtos = await usersService.convertToDtos(users: users.data, attachSensitive: false, on: request.executionContext)
        
        return LinkableResultDto(
            maxId: users.maxId,
            minId: users.minId,
            data: userDtos
        )
    }
    
    /// Exposing home timeline.
    ///
    /// This is the endpoint that is most important to the logged-in user.
    /// It returns a list of statuses added by users followed by the logged-in user.
    ///
    /// Optional query params:
    /// - `onlyLocal` - `true` if list should contain only statuses added on local instance
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/timelines/home`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/timelines/home" \
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
    ///             "category": {
    ///                 "id": "7302429509785630721",
    ///                 "name": "Street"
    ///             },
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
    func home(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let authorizationPayloadId = try request.requireUserId()

        let linkableParams = request.linkableParams()
        let timelineService = request.application.services.timelineService
        let statuses = try await timelineService.home(for: authorizationPayloadId, linkableParams: linkableParams, on: request.db)
        
        let statusesService = request.application.services.statusesService
        let statusDtos = await statusesService.convertToDtos(statuses: statuses.data, on: request.executionContext)
        
        return LinkableResultDto(
            maxId: statuses.maxId,
            minId: statuses.minId,
            data: statusDtos
        )
    }
}
