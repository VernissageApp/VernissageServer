//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension ReportsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("reports")
    
    func boot(routes: RoutesBuilder) throws {
        let reportsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(ReportsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        reportsGroup
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(EventHandlerMiddleware(.reportsList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
        
        reportsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.reportsCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: create)
        
        reportsGroup
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.reportsClose))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":id", "close", use: close)
        
        reportsGroup
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.reportsRestore))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":id", "restore", use: restore)
    }
}

/// Controller for managing user's reports.
///
/// Controller to manage reports of rule violations by system users.
/// It allows you to view the list of reports, close or restore reports.
///
/// > Important: Base controller URL: `/api/v1/reports`.
struct ReportsController {
    
    /// List of reports.
    ///
    /// Endpoint, returning a list of reports submitted by all users of the system.
    /// The report is always associated with the user who reports and the user
    /// being reported and sometimes with a status.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    ///
    /// > Important: Endpoint URL: `/api/v1/reports`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/reports?page=0&limit=10" \
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
    ///             "category": "",
    ///             "comment": "Report comment",
    ///             "createdAt": "2023-12-10T06:52:57.929Z",
    ///             "forward": false,
    ///             "id": "7310855385217409025",
    ///             "reportedUser": {
    ///                 "account": "johndoe@localhost",
    ///                 "activityPubProfile": "http://localhost:8080/actors/johndoe",
    ///                 "createdAt": "2023-07-26T13:52:27.590Z",
    ///                 "followersCount": 0,
    ///                 "followingCount": 0,
    ///                 "id": "7260124605905795073",
    ///                 "isLocal": true,
    ///                 "name": "John Doe",
    ///                 "statusesCount": 4,
    ///                 "updatedAt": "2023-12-09T13:49:39.035Z",
    ///                 "userName": "johndoe"
    ///             },
    ///             "ruleIds": [],
    ///             "status": { ... },
    ///             "updatedAt": "2023-12-10T06:52:57.929Z",
    ///             "user": { ... }
    ///         }
    ///     ],
    ///     "page": 1,
    ///     "size": 10,
    ///     "total": 10
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of paginable reports.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<ReportDto> {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.executionContext)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        
        let reportsFromDatabase = try await Report.query(on: request.db)
            .with(\.$user)
            .with(\.$reportedUser)
            .with(\.$considerationUser)
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: size))
        
        let reportDtos = await reportsFromDatabase.items.asyncMap({
            let statusDto = try? await self.getStatusDto(report: $0, on: request)
            return ReportDto(from: $0, status: statusDto, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
        })
        
        return PaginableResultDto(
            data: reportDtos,
            page: reportsFromDatabase.metadata.page,
            size: reportsFromDatabase.metadata.per,
            total: reportsFromDatabase.metadata.total
        )
    }
    
    /// Creating new report.
    ///
    /// Endpoint, used for adding new reports by users.
    ///
    /// > Important: Endpoint URL: `/api/v1/reports`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/reports" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "forward": false,
    ///     "reportedUserId": "7250729777261258753",
    ///     "statusId": "7333524055101671425",
    ///     "category": "Abusive",
    ///     "comment": "This is very rude comment.",
    ///     "ruleIds": [
    ///         1
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `EntityNotFoundError.statusNotFound` if status not exists.
    @Sendable
    func create(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let reportRequestDto = try request.content.decode(ReportRequestDto.self)
        try ReportRequestDto.validate(content: request)
         
        guard let reportedUserId = reportRequestDto.reportedUserId.toId() else {
            throw Abort(.badRequest)
        }
        
        guard let user = try await User.query(on: request.db).filter(\.$id == reportedUserId).first() else {
            throw EntityNotFoundError.userNotFound
        }
        
        if let statusId = reportRequestDto.statusId?.toId() {
            guard let _ = try await Status.query(on: request.db).filter(\.$id == statusId).first() else {
                throw EntityNotFoundError.statusNotFound
            }
        }
        
        let statusesService = request.application.services.statusesService
        let mainStatus = try await statusesService.getMainStatus(for: reportRequestDto.statusId?.toId(), on: request.db)
        
        let id = request.application.services.snowflakeService.generate()
        let report = Report(
            id: id,
            userId: authorizationPayloadId,
            reportedUserId: reportedUserId,
            statusId: reportRequestDto.statusId?.toId(),
            mainStatusId: mainStatus?.id,
            comment: reportRequestDto.comment,
            forward: reportRequestDto.forward,
            category: reportRequestDto.category,
            ruleIds: reportRequestDto.ruleIds
        )
                
        // Save new report in database.
        try await report.save(on: request.db)
        
        // Send notifications about new report.
        try await self.sendNotifications(user: user, on: request)
        
        return HTTPStatus.created
    }
    
    /// Closing report.
    ///
    /// Endpoint, used for closing existnig report.
    ///
    /// > Important: Endpoint URL: `/api/v1/reports/:id/close`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/reports/7333615812782637057/close" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "category": "Abusive",
    ///     "comment": "This is very rude comment.",
    ///     "considerationDate": "2024-02-09T15:07:45.796Z",
    ///     "considerationUser": { ... },
    ///     "createdAt": "2024-02-09T15:00:34.605Z",
    ///     "forward": false,
    ///     "id": "7333615812782637057",
    ///     "reportedUser": { ... },
    ///     "ruleIds": [
    ///         "1"
    ///     ],
    ///     "status": { ... },
    ///     "updatedAt": "2024-02-09T15:07:45.796Z",
    ///     "user": { ... }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about report.
    ///
    /// - Throws: `EntityNotFoundError.reportNotFound` if report not exists.
    @Sendable
    func close(request: Request) async throws -> ReportDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let reportId = request.parameters.get("id")?.toId() else {
            throw Abort(.badRequest)
        }
        
        guard let report = try await Report.query(on: request.db)
            .filter(\.$id == reportId)
            .first() else {
            throw EntityNotFoundError.reportNotFound
        }
        
        report.$considerationUser.id = authorizationPayloadId
        report.considerationDate = Date()
        try await report.save(on: request.db)
        
        guard let reportFromDatabase = try await Report.query(on: request.db)
            .filter(\.$id == reportId)
            .with(\.$user)
            .with(\.$reportedUser)
            .with(\.$considerationUser)
            .first() else {
            throw EntityNotFoundError.reportNotFound
        }
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.executionContext)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let statusDto = try? await self.getStatusDto(report: reportFromDatabase, on: request)
        return ReportDto(from: reportFromDatabase, status: statusDto, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
    }
    
    /// Restoring report.
    ///
    /// Endpoint, used for restoring existnig report.
    ///
    /// > Important: Endpoint URL: `/api/v1/reports/:id/restore`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/reports/7333615812782637057/restore" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "category": "Abusive",
    ///     "comment": "This is very rude comment.",
    ///     "considerationDate": "2024-02-09T15:07:45.796Z",
    ///     "considerationUser": { ... },
    ///     "createdAt": "2024-02-09T15:00:34.605Z",
    ///     "forward": false,
    ///     "id": "7333615812782637057",
    ///     "reportedUser": { ... },
    ///     "ruleIds": [
    ///         "1"
    ///     ],
    ///     "status": { ... },
    ///     "updatedAt": "2024-02-09T15:07:45.796Z",
    ///     "user": { ... }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about report.
    ///
    /// - Throws: `EntityNotFoundError.reportNotFound` if report not exists.
    @Sendable
    func restore(request: Request) async throws -> ReportDto {
        guard let reportId = request.parameters.get("id")?.toId() else {
            throw Abort(.badRequest)
        }
        
        guard let report = try await Report.query(on: request.db)
            .filter(\.$id == reportId)
            .first() else {
            throw EntityNotFoundError.reportNotFound
        }
        
        report.$considerationUser.id = nil
        report.considerationDate = nil
        try await report.save(on: request.db)
        
        guard let reportFromDatabase = try await Report.query(on: request.db)
            .filter(\.$id == reportId)
            .with(\.$user)
            .with(\.$reportedUser)
            .with(\.$considerationUser)
            .first() else {
            throw EntityNotFoundError.reportNotFound
        }
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.executionContext)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let statusDto = try? await self.getStatusDto(report: reportFromDatabase, on: request)
        return ReportDto(from: reportFromDatabase, status: statusDto, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
    }
    
    private func getStatusDto(report: Report, on request: Request) async throws -> StatusDto? {
        guard let statusId = report.$status.id else {
            return nil
        }
        
        let statusesService = request.application.services.statusesService
        guard let status = try await statusesService.getOrginalStatus(id: statusId, on: request.db) else {
            return nil
        }
        
        return await statusesService.convertToDto(status: status, attachments: status.attachments, attachUserInteractions: true, on: request.executionContext)
    }
    
    private func sendNotifications(user: User, on request: Request) async throws {
        let notificationsService = request.application.services.notificationsService
        let usersService = request.application.services.usersService

        let moderators = try await usersService.getModerators(on: request.db)
        for moderator in moderators {
            try await notificationsService.create(type: .adminReport,
                                                  to: moderator,
                                                  by: user.requireID(),
                                                  statusId: nil,
                                                  mainStatusId: nil,
                                                  on: request.executionContext)
        }
    }
}
