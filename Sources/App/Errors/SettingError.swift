//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum SettingError: String, Error {
    case incorrectSettingId
}

extension SettingError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectSettingId: return "Setting id is incorrect."
        }
    }

    var identifier: String {
        return "setting"
    }

    var code: String {
        return self.rawValue
    }
}
