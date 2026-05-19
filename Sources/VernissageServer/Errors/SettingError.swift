//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned when operating system settings.
enum SettingError: String, Error {
    case incorrectSettingId
    case settingsKeyCannotBeChanged
}

extension SettingError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectSettingId: return "Setting id is incorrect."
        case .settingsKeyCannotBeChanged: return "Setting key cannot be changed."
        }
    }

    var parameters: [String : String]? {
        return nil
    }
    
    var identifier: String {
        return "setting"
    }

    var code: String {
        return self.rawValue
    }
}
