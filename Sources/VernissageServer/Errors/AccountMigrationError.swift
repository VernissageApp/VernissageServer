//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum AccountMigrationError: String, Error {
    case targetAccountNotFound
    case cannotMoveToTheSameAccount
    case targetAccountIsNotAlias
    case onlyLocalAccountsCanBeMoved
}

extension AccountMigrationError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        .badRequest
    }
    
    var reason: String {
        switch self {
        case .targetAccountNotFound: return "Target account cannot be found."
        case .cannotMoveToTheSameAccount: return "Target account cannot be equal to source account."
        case .targetAccountIsNotAlias: return "Target account is not an alias of this account."
        case .onlyLocalAccountsCanBeMoved: return "Only local accounts can be moved."
        }
    }
    
    var identifier: String {
        "account-migration"
    }
    
    var code: String {
        self.rawValue
    }
}
