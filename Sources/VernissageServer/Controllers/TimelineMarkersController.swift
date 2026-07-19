//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension TimelineMarkersController: RouteCollection {

    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("timeline-markers")

    func boot(routes: RoutesBuilder) throws {
        let timelineMarkersGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(TimelineMarkersController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())

        timelineMarkersGroup
            .grouped(EventHandlerMiddleware(.timelineMarkersRead))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":timeline", use: read)

        timelineMarkersGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.timelineMarkersUpdate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":timeline", use: update)
    }
}

/// Controller for managing markers of statuses already watched on timelines.
///
/// The controller stores and returns the last status watched by the authenticated user
/// separately for each supported timeline.
///
/// > Important: Base controller URL: `/api/v1/timeline-markers`.
struct TimelineMarkersController {

    /// Get the last status watched on a timeline.
    ///
    /// > Important: Endpoint URL: `/api/v1/timeline-markers/:timeline`.
    ///
    /// Supported timeline values: `private`, `local`, `federated`, and `featured`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/timeline-markers/local" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "statusId": "7310891166589564929"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: The last watched status identifier for the selected timeline.
    ///
    /// - Throws: `TimelineMarkerError.incorrectTimeline` if timeline is incorrect.
    /// - Throws: `EntityNotFoundError.timelineMarkerNotFound` if marker does not exist.
    @Sendable
    func read(request: Request) async throws -> TimelineMarkerDto {
        let authorizationPayloadId = try request.requireUserId()
        let timeline = try self.timelineKind(from: request)

        guard let timelineMarker = try await TimelineMarker.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$timeline == timeline)
            .first() else {
            throw EntityNotFoundError.timelineMarkerNotFound
        }

        return TimelineMarkerDto(statusId: "\(timelineMarker.$status.id)")
    }

    /// Create or update the last status watched on a timeline.
    ///
    /// > Important: Endpoint URL: `/api/v1/timeline-markers/:timeline`.
    ///
    /// Supported timeline values: `private`, `local`, `federated`, and `featured`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/timeline-markers/local" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ "statusId": "7310891166589564929" }'
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `TimelineMarkerError.incorrectTimeline` if timeline is incorrect.
    /// - Throws: `TimelineMarkerError.incorrectStatusId` if status id is incorrect.
    /// - Throws: `EntityNotFoundError.statusNotFound` if status does not exist.
    @Sendable
    func update(request: Request) async throws -> HTTPResponseStatus {
        let authorizationPayloadId = try request.requireUserId()
        let timeline = try self.timelineKind(from: request)
        let timelineMarkerDto = try request.content.decode(TimelineMarkerDto.self)

        guard let statusId = timelineMarkerDto.statusId.toId() else {
            throw TimelineMarkerError.incorrectStatusId
        }

        guard try await Status.query(on: request.db)
            .filter(\.$id == statusId)
            .first() != nil else {
            throw EntityNotFoundError.statusNotFound
        }

        if let timelineMarker = try await TimelineMarker.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .filter(\.$timeline == timeline)
            .first() {
            timelineMarker.$status.id = statusId
            try await timelineMarker.save(on: request.db)
        } else {
            let id = request.application.services.snowflakeService.generate()
            let timelineMarker = TimelineMarker(
                id: id,
                statusId: statusId,
                userId: authorizationPayloadId,
                timeline: timeline
            )

            try await timelineMarker.create(on: request.db)
        }

        return .ok
    }

    private func timelineKind(from request: Request) throws -> TimelineKind {
        guard let timelineString = request.parameters.get("timeline"),
              let timelineKindDto = TimelineKindDto(rawValue: timelineString) else {
            throw TimelineMarkerError.incorrectTimeline
        }

        return timelineKindDto.translate()
    }
}
