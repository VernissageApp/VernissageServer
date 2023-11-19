//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

final class ReportsController: RouteCollection {
    
    public static let uri: PathComponent = .constant("reports")
    
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
            .get(use: list)
        
        reportsGroup
            .grouped(EventHandlerMiddleware(.reportsCreate))
            .post(use: create)
        
        reportsGroup
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(EventHandlerMiddleware(.reportsClose))
            .post(":id", "close", use: close)
        
        reportsGroup
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(EventHandlerMiddleware(.reportsRestore))
            .post(":id", "restore", use: restore)
    }
    
    /// List of reports.
    func list(request: Request) async throws -> PaginableResultDto<ReportDto> {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        
        let reportsFromDatabase = try await Report.query(on: request.db)
            .with(\.$user)
            .with(\.$reportedUser)
            .with(\.$considerationUser)
            .with(\.$status)
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
    func create(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let reportRequestDto = try request.content.decode(ReportRequestDto.self)
        try ReportRequestDto.validate(content: request)
         
        guard let reportedUserId = reportRequestDto.reportedUserId.toId() else {
            throw Abort(.badRequest)
        }
        
        guard let _ = try await User.query(on: request.db).filter(\.$id == reportedUserId).first() else {
            throw EntityNotFoundError.userNotFound
        }
        
        if let statusId = reportRequestDto.statusId?.toId() {
            guard let _ = try await Status.query(on: request.db).filter(\.$id == statusId).first() else {
                throw EntityNotFoundError.statusNotFound
            }
        }
        
        let report = Report(
            userId: authorizationPayloadId,
            reportedUserId: reportedUserId,
            statusId: reportRequestDto.statusId?.toId(),
            comment: reportRequestDto.comment,
            forward: reportRequestDto.forward,
            category: reportRequestDto.category,
            ruleIds: reportRequestDto.ruleIds
        )
        
        try await report.save(on: request.db)
        return HTTPStatus.created
    }
    
    /// Closing report.
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
            .with(\.$status)
            .first() else {
            throw EntityNotFoundError.reportNotFound
        }
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let statusDto = try? await self.getStatusDto(report: reportFromDatabase, on: request)
        return ReportDto(from: reportFromDatabase, status: statusDto, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
    }
    
    /// Restoring report.
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
            .with(\.$status)
            .first() else {
            throw EntityNotFoundError.reportNotFound
        }
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
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
        
        return await statusesService.convertToDtos(on: request, status: status, attachments: status.attachments)
    }
}
