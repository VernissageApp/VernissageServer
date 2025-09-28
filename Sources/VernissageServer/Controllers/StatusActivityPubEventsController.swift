//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension StatusActivityPubEventsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("status-activity-pub-events")

    func boot(routes: RoutesBuilder) throws {
        let eventsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(StatusActivityPubEventsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())

        eventsGroup
            .grouped(EventHandlerMiddleware(.statusActivityPubEventsList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
        
        eventsGroup
            .grouped(EventHandlerMiddleware(.statusesEventItems))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":eventId", "items", use: eventItems)
    }
}

/// Controller for managing the Activity Pub events (mainly for statuses).
///
/// With this controller, the administrator/moderator can view events send to other instances.
///
/// > Important: Base controller URL: `/api/v1/status-activity-pub-events`.
struct StatusActivityPubEventsController {
    /// List of ActivityPub events.
    ///
    /// The endpoint returns a paginated list of ActivityPub processing events.
    /// Only moderators, or administrators can access this endpoint.
    /// You can filter results by event `type` and processing `result`, and control sorting and pagination.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    /// - `type` - filter by event type (e.g. `create`, `update`, `like`, `unlike`, `announce`, `unannounce`)
    /// - `result` - filter by processing result (e.g. `waiting`, `processing`, `finished`, `finishedWithErrors`, `failed`)
    /// - `sortDirection` - direction of sorting (possible values: `ascending` or `descending`)
    /// - `sortColumn` - column used for sorting (possible values: `startAt`, `endAt`, `createdAt` or `updatedAt`)
    ///
    /// > Important: Endpoint URL: `/api/v1/status-activity-pub-events`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/status-activity-pub-events" \
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
    ///             "id": "7267938074834522113",
    ///             "user": {
    ///                ...
    ///             },
    ///             "type": "create",
    ///             "result": "finishedWithErrors",
    ///             "errorMessage": "Something went wrong.",
    ///             "attempts": "1",
    ///             "startAt": "2023-08-16T15:13:12.607Z",
    ///             "endAt": "2023-08-16T15:13:21.607Z",
    ///             "createdAt": "2023-08-16T15:10:08.607Z",
    ///             "updatedAt": "2023-08-16T15:23:08.607Z",
    ///         }
    ///     ],
    ///     "page": 1,
    ///     "size": 10,
    ///     "total": 176
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of paginable status ActivityPub events.
    ///
    /// - Throws: `StatusActivityPubEventError.sortColumnNotSupported` if `sortColumn` is not supported.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<StatusActivityPubEventDto> {
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        let typeString: String = request.query["type"] ?? ""
        let resultString: String = request.query["result"] ?? ""
        
        let type = StatusActivityPubEventTypeDto(rawValue: typeString)?.translate()
        let result = StatusActivityPubEventResultDto(rawValue: resultString)?.translate()
        
        let eventsFromDatabaseQueryBuilder = StatusActivityPubEvent.query(on: request.db)
            .with(\.$user)
                    
        if let type {
            eventsFromDatabaseQueryBuilder
                .filter(\.$type == type)
        }
        
        if let result {
            eventsFromDatabaseQueryBuilder
                .filter(\.$result == result)
        }
        
        // Read sort direction from request query string.
        let sortDirection: DatabaseQuery.Sort.Direction = if let sortDirectionString: String = request.query["sortDirection"] {
            sortDirectionString == "ascending" ? .ascending : .descending
        } else {
            .descending
        }
        
        // Read sort column from request query string.
        if let sortColumnName: String = request.query["sortColumn"] {
            switch sortColumnName {
            case "startAt":
                eventsFromDatabaseQueryBuilder.sort(\.$startAt, sortDirection)
            case "endAt":
                eventsFromDatabaseQueryBuilder.sort(\.$endAt, sortDirection)
            case "createdAt":
                eventsFromDatabaseQueryBuilder.sort(\.$createdAt, sortDirection)
            case "updatedAt":
                eventsFromDatabaseQueryBuilder.sort(\.$updatedAt, sortDirection)
            default:
                throw StatusActivityPubEventError.sortColumnNotSupported
            }
        } else {
            eventsFromDatabaseQueryBuilder.sort(\.$createdAt, sortDirection)
        }

        let eventsFromDatabase = try await eventsFromDatabaseQueryBuilder
            .paginate(PageRequest(page: page, per: size))
        
        let statusesService = request.application.services.statusesService
        let eventsDtos = await statusesService.convertToDtos(statusActivityPubEvents: eventsFromDatabase.items, on: request.executionContext)

        return PaginableResultDto(
            data: eventsDtos,
            page: eventsFromDatabase.metadata.page,
            size: eventsFromDatabase.metadata.per,
            total: eventsFromDatabase.metadata.total
        )
    }
    
    /// List of ActivityPub event items.
    ///
    /// The endpoint returns a paginated list of ActivityPub processing event items related to the specified event.
    /// Only moderators, or administrators can access this endpoint.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    /// - `onlyErrors` - return only items with error
    /// - `sortDirection` - direction of sorting (possible values: `ascending` or `descending`)
    /// - `sortColumn` - column used for sorting (possible values: `startAt`, `endAt`, `createdAt` or `updatedAt`)
    ///
    /// > Important: Endpoint URL: `/api/v1/status-activity-pub-events/:eventId/items`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/status-activity-pub-events/:eventId/items" \
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
    ///             "id": "7267938074834522113",
    ///             "url": "https://example.com/sharedurl",
    ///             "isSuccess": false,
    ///             "errorMessage": "Something went wrong.",
    ///             "startAt": "2023-08-16T15:13:12.607Z",
    ///             "endAt": "2023-08-16T15:13:21.607Z",
    ///             "createdAt": "2023-08-16T15:10:08.607Z",
    ///             "updatedAt": "2023-08-16T15:23:08.607Z",
    ///         }
    ///     ],
    ///     "page": 1,
    ///     "size": 10,
    ///     "total": 176
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of paginable status ActivityPub event items.
    ///
    /// - Throws: `EntityNotFoundError.statusActivityPubEventNotFound` if event not found.
    /// - Throws: `StatusActivityPubEventError.sortColumnNotSupported` if `sortColumn` is not supported.
    @Sendable
    func eventItems(request: Request) async throws -> PaginableResultDto<StatusActivityPubEventItemDto> {
        guard let eventIdString = request.parameters.get("eventId", as: String.self) else {
            throw StatusError.incorrectStatusEventId
        }
        
        guard let eventId = eventIdString.toId() else {
            throw StatusError.incorrectStatusEventId
        }
        
        let statusActivityPubEvent = try await StatusActivityPubEvent.query(on: request.db)
            .with(\.$user)
            .with(\.$status)
            .filter(\.$id == eventId)
            .first()
        
        guard statusActivityPubEvent != nil else {
            throw EntityNotFoundError.statusActivityPubEventNotFound
        }
        
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        let onlyErrors: Bool? = request.query["onlyErrors"] ?? false
        
        let eventItemsFromDatabaseQueryBuilder = StatusActivityPubEventItem.query(on: request.db)
            .filter(\.$statusActivityPubEvent.$id == eventId)
                    
        if onlyErrors == true {
            eventItemsFromDatabaseQueryBuilder
                .filter(\.$isSuccess == false)
        }
        
        // Read sort direction from request query string.
        let sortDirection: DatabaseQuery.Sort.Direction = if let sortDirectionString: String = request.query["sortDirection"] {
            sortDirectionString == "ascending" ? .ascending : .descending
        } else {
            .descending
        }
        
        // Read sort column from request query string.
        if let sortColumnName: String = request.query["sortColumn"] {
            switch sortColumnName {
            case "startAt":
                eventItemsFromDatabaseQueryBuilder.sort(\.$startAt, sortDirection)
            case "endAt":
                eventItemsFromDatabaseQueryBuilder.sort(\.$endAt, sortDirection)
            case "createdAt":
                eventItemsFromDatabaseQueryBuilder.sort(\.$createdAt, sortDirection)
            case "updatedAt":
                eventItemsFromDatabaseQueryBuilder.sort(\.$updatedAt, sortDirection)
            default:
                throw StatusError.sortColumnNotSupported
            }
        } else {
            eventItemsFromDatabaseQueryBuilder.sort(\.$createdAt, sortDirection)
        }

        let eventsFromDatabase = try await eventItemsFromDatabaseQueryBuilder
            .paginate(PageRequest(page: page, per: size))
        
        let statusesService = request.application.services.statusesService
        let eventsDtos = await statusesService.convertToDtos(statusActivityPubEventItems: eventsFromDatabase.items, on: request.executionContext)

        return PaginableResultDto(
            data: eventsDtos,
            page: eventsFromDatabase.metadata.page,
            size: eventsFromDatabase.metadata.per,
            total: eventsFromDatabase.metadata.total
        )
    }
}
