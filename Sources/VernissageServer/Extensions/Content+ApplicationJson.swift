//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension Content {
    public func encodeActivityResponse(for request: Request) async throws -> Response {
        let response = try await self.encodeResponse(for: request)
        response.headers.contentType = Constants.activityJsonContentType
        response.status = .ok
        
        return response
    }
}

