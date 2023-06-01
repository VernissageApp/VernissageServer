//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct LoginHandlerMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        
        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        if appplicationSettings?.eventsToStore.contains(.accountLogin) == false {
            return next.respond(to: request)
        }
        
        let event = Event(type: .accountLogin,
                          method: request.method,
                          uri: request.url.description,
                          wasSuccess: false,
                          requestBody: self.getSecureRequestBody(from: request))
    
        return next.respond(to: request).always { result in
            switch result {
            case .success(let response):
                event.responseBody = response.body.string
                event.wasSuccess = true
                event.userId = request.auth.get(UserPayload.self)?.id
            case .failure(let error):
                event.error = error.localizedDescription
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
    
    private func getSecureRequestBody(from request: Request) -> String? {
        do {
            var loginRequestDto = try request.content.decode(LoginRequestDto.self)
            loginRequestDto.password = "********"
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(loginRequestDto)
            return String(data: data, encoding: .utf8)
        } catch {
            request.logger.error("Error during decoding access token during logging.")
            return nil
        }
    }
}
