//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension RefreshToken {

    static func get(token: String) async throws -> RefreshToken {
        guard let refreshToken = try await RefreshToken.query(on: SharedApplication.application().db).filter(\.$token == token).first() else {
            throw SharedApplicationError.unwrap
        }

        return refreshToken
    }
}
