//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension QuickCaptchaController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("quick-captcha")
    
    func boot(routes: RoutesBuilder) throws {
        let captchaGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(QuickCaptchaController.uri)
        
        captchaGroup
            .grouped(EventHandlerMiddleware(.quickCaptchaGenerate))
            .grouped(CacheControlMiddleware(.noStore))
            .get("generate", use: generate)
    }
}

/// Controller for managing the requests for captcha.
///
/// > Important: Base controller URL: `/api/v1/quick-captcha`.
struct QuickCaptchaController {
    /// Default key lenght which have to be provided by the client.
    private let keyLength = 16

    /// Get image with rendered text.
    ///
    /// An endpoint that returns image with rendered text which should be hard to read by bots.
    ///
    /// > Important: Endpoint URL: `/api/v1/quick-captcha/generate`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/quick-captcha/generate" \
    /// -X GET
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Image binary data.
    ///
    /// - Throws: `QuickCaptchaError.keyLengthIsIncorrect` if given key is invalid (should contain exactly 16 characters).
    @Sendable
    func generate(request: Request) async throws -> Response {
        let key = request.query["key"] ?? ""
        guard key.count == self.keyLength else {
            throw QuickCaptchaError.keyLengthIsIncorrect
        }
        
        let quickCaptchaService = request.application.services.quickCaptchaService
        let image = try await quickCaptchaService.generate(key: key, on: request.executionContext)
        
        return Response(status: .ok,
                        headers: ["Content-Type": "image/jpeg"],
                        body: .init(data: image))
    }
}
