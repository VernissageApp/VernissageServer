//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

/// Exposing list of supported licenses.
final class LicensesController: RouteCollection {
    
    public static let uri: PathComponent = .constant("licenses")
    
    func boot(routes: RoutesBuilder) throws {
        let locationsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(LicensesController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        locationsGroup
            .grouped(EventHandlerMiddleware(.licensesList))
            .get(use: list)
    }
    
    /// Exposing list of licenses.
    func list(request: Request) async throws -> [LicenseDto] {
        let licenses = try await License.query(on: request.db)
            .sort(\.$id)
            .all()

        return licenses.map({ LicenseDto(from: $0) })
    }
}
