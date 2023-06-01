//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTVapor
import Fluent

extension RefreshToken {

    static func get(token: String) throws -> RefreshToken {
        guard let refreshToken = try RefreshToken.query(on: SharedApplication.application().db).filter(\.$token == token).first().wait() else {
            throw SharedApplicationError.unwrap
        }

        return refreshToken
    }
}
