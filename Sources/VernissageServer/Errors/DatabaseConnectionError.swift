//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during database connection errors
enum DatabaseConnectionError: String, Error {
    case userNameNotSpecified
    case passwordNotSpecified
    case hostNotSpecified
    case portNotSpecified
    case databaseNotSpecified
}

extension DatabaseConnectionError: TerminateError {
    var status: HTTPResponseStatus {
        return .internalServerError
    }

    var reason: String {
        switch self {
        case .userNameNotSpecified: return "User name is not specified in connection string. Propert format is: "
            + "'// postgresql://username:password@host:port/database?sslmode=require'."
        case .passwordNotSpecified: return "Password is not specified in connection string. Propert format is: "
            + "'// postgresql://username:password@host:port/database?sslmode=require'."
        case .hostNotSpecified: return "Host is not specified in connection string. Propert format is: "
            + "'// postgresql://username:password@host:port/database?sslmode=require'."
        case .portNotSpecified: return "Port is not specified in connection string. Propert format is: "
            + "'// postgresql://username:password@host:port/database?sslmode=require'."
        case .databaseNotSpecified: return "Database name is not specified in connection string. Propert format is: "
            + "'// postgresql://username:password@host:port/database?sslmode=require'."
        }
    }

    var identifier: String {
        return "database"
    }

    var code: String {
        return self.rawValue
    }
}
