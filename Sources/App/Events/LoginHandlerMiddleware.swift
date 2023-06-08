//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct LoginHandlerMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        
        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        if appplicationSettings?.eventsToStore.contains(.accountLogin) == false {
            return try await next.respond(to: request)
        }
        
        let event = Event(type: .accountLogin,
                          method: request.method,
                          uri: request.url.description,
                          wasSuccess: false,
                          requestBody: self.getSecureRequestBody(from: request))
    
        do {
            let response = try await next.respond(to: request)
            
            event.responseBody = response.body.string
            event.wasSuccess = true
            event.userId = request.auth.get(UserPayload.self)?.id.toId()
            
            try? await event.save(on: request.db)
            return response
        } catch {
            event.error = error.localizedDescription
            
            try? await event.save(on: request.db)
            throw error
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
