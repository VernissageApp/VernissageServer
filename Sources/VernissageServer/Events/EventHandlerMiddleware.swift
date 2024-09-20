//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Middleware that allows for logging calls to specific endpoints in the system.
struct EventHandlerMiddleware: AsyncMiddleware {
    private let eventType: EventType
    private let storeRequest: Bool
    
    init(_ eventType: EventType, storeRequest: Bool = true) {
        self.eventType = eventType
        self.storeRequest = storeRequest
    }
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        
        let appplicationSettings = request.application.settings.cached
        if appplicationSettings?.eventsToStore.contains(self.eventType) == false {
            return try await next.respond(to: request)
        }
        
        let userAgent = request.headers[.userAgent].first
        let id = request.application.services.snowflakeService.generate()
        let event = Event(id: id,
                          type: self.eventType,
                          method: request.method,
                          uri: request.url.description,
                          wasSuccess: false,
                          requestBody: self.storeRequest ? request.body.string : nil,
                          userAgent: userAgent)
    
        do {
            let response = try await next.respond(to: request)
            
            event.wasSuccess = true
            event.responseBody = response.body.string
            event.userId = request.auth.get(UserPayload.self)?.id.toId()
            
            try? await event.save(on: request.db)
            return response
        } catch {
            event.error = error.localizedDescription
            event.userId = request.auth.get(UserPayload.self)?.id.toId()
            
            try? await event.save(on: request.db)
            throw error
        }
    }
}
