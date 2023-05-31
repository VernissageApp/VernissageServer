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
