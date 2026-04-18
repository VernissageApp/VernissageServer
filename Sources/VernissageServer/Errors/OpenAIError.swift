//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during using OpenAI endpoints.
enum OpenAIError: Error {
    case incorrectOpenAIUrl
    case cannotChangeResponseToString
    case incorrectJsonFormat
    case openAIIsNotEnabled
    case openAIIsNotConfigured(String)
}

extension OpenAIError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .incorrectOpenAIUrl: return .badRequest
        case .cannotChangeResponseToString: return .internalServerError
        case .incorrectJsonFormat: return .internalServerError
        case .openAIIsNotEnabled: return .forbidden
        case .openAIIsNotConfigured: return .internalServerError
        }
    }

    var reason: String {
        switch self {
        case .incorrectOpenAIUrl: return "Incorrect OpenAI url."
        case .cannotChangeResponseToString: return "Cannot change response to string."
        case .incorrectJsonFormat: return "Incorrect JSON format."
        case .openAIIsNotEnabled: return "OpenAI is not enabled."
        case .openAIIsNotConfigured(let message): return "OpenAI is not configured. \(message)"
        }
    }

    var identifier: String {
        return "openAI"
    }

    var code: String {
        switch self {
        case .incorrectOpenAIUrl: return "incorrectOpenAIUrl"
        case .cannotChangeResponseToString: return "cannotChangeResponseToString"
        case .incorrectJsonFormat: return "incorrectJsonFormat"
        case .openAIIsNotEnabled: return "openAIIsNotEnabled"
        case .openAIIsNotConfigured: return "openAIIsNotConfigured"
        }
    }
}
