//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

final class SearchController: RouteCollection {
    
    public static let uri: PathComponent = .constant("search")
    
    func boot(routes: RoutesBuilder) throws {
        let searchGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(SearchController.uri)
        
        searchGroup
            .grouped(EventHandlerMiddleware(.search))
            .get(use: search)
    }
    
    func search(request: Request) async throws -> UserDto {
        let usersService = request.application.services.usersService

        // Check query.
        let query: String? = request.query["q"]
        guard let query else {
            throw Abort(.badRequest)
        }
        
        // TODO: Verify blocked domain.
        
        // TODO: improve domain extract and create local search also.
        // Search user profile by webfinger.
        let domain = query.split(separator: "@").last ?? ""
        let baseUrl = URL(string: "https://\(domain)")
        let activityPubClient = ActivityPubClient(baseURL: baseUrl!)
        let response = try await activityPubClient.webfinger(resource: query)
                
        // Download resources.
        guard let activityPubProfile = response.links.first(where: { $0.rel == "self" })?.href else {
            throw Abort(.notFound)
        }
        
        guard let personProfile = try? await activityPubClient.person(id: activityPubProfile) else {
            throw Abort(.notFound)
        }
        
        // Get user based on ActivityPubProfile from internal database.
        let userFromDb = try await usersService.get(on: request, activityPubProfile: personProfile.id)
        
        // If user not exist we have to create his account in internal database and return it.
        if userFromDb == nil {
            let newUser = try await usersService.create(on: request, basedOn: personProfile)
            return UserDto(from: newUser)
        } else {
            // If user exist then we have to update uhis account in internal database and return it.
            let updatedUser = try await usersService.update(user: userFromDb!, on: request, basedOn: personProfile)
            return UserDto(from: updatedUser)
        }
    }
}
