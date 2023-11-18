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
            .grouped(EventHandlerMiddleware(.reportsCreate))
            .post(use: create)
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
        
        if let statusId = reportRequestDto.statusId {
            guard let _ = try await Status.query(on: request.db).filter(\.$id == statusId).first() else {
                throw EntityNotFoundError.statusNotFound
            }
        }
        
        let report = Report(
            userId: authorizationPayloadId,
            reportedUserId: reportedUserId,
            statusId: reportRequestDto.statusId,
            comment: reportRequestDto.comment,
            forward: reportRequestDto.forward,
            category: reportRequestDto.category,
            ruleIds: reportRequestDto.ruleIds
        )
        
        try await report.save(on: request.db)
        return HTTPStatus.created
    }
}
