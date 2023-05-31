import Vapor
import ExtendedError

enum AuthClientError: String, Error {
    case authClientWithUriExists
    case incorrectAuthClientId
}

extension AuthClientError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .authClientWithUriExists: return "Authentication client with specified uri already exists."
        case .incorrectAuthClientId: return "Authentication client id is incorrect."
        }
    }

    var identifier: String {
        return "auth-client"
    }

    var code: String {
        return self.rawValue
    }
}
