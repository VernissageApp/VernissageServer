//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

final class TimelinesController: RouteCollection {
    
    public static let uri: PathComponent = .constant("timelines")
    
    func boot(routes: RoutesBuilder) throws {
        let timelinesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(TimelinesController.uri)
        
        timelinesGroup
            .grouped(EventHandlerMiddleware(.timelinesPublic))
            .get("public", use: list)
        
        timelinesGroup
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.timelinesPublic))
            .get("home", use: home)
    }
    
    /// Exposing public timeline.
    func list(request: Request) async throws -> [String] {
        return []
    }
    
    /// Exposing home timeline.
    func home(request: Request) async throws -> [String] {
        return []
    }
}
