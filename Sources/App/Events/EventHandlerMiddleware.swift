//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct EventHandlerMiddleware: Middleware {
    private let eventType: EventType
    private let storeRequest: Bool
    
    init(_ eventType: EventType, storeRequest: Bool = true) {
        self.eventType = eventType
        self.storeRequest = storeRequest
    }
    
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        
        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        if appplicationSettings?.eventsToStore.contains(self.eventType) == false {
            return next.respond(to: request)
        }
        
        let event = Event(type: self.eventType,
                          method: request.method,
                          uri: request.url.description,
                          wasSuccess: false,
                          requestBody: self.storeRequest ? request.body.string : nil)
    
        return next.respond(to: request).always { result in
            switch result {
            case .success(let response):
                event.wasSuccess = true
                event.responseBody = response.body.string
                event.userId = request.auth.get(UserPayload.self)?.id
            case .failure(let error):
                event.error = error.localizedDescription
                event.userId = request.auth.get(UserPayload.self)?.id
            }
        }.flatMap { response in
            return event.save(on: request.db).map { _ in
                return response
            }
            
        }.flatMapError { error -> EventLoopFuture<Response> in
            return event.save(on: request.db).flatMap { _ in
                request.fail(error)
            }
        }
    }
}
