//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum NetworkError: Error {
    case notSuccessResponse(URLResponse, Data?)
    case jsonDecodeError
    case unknownError
}

extension NetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notSuccessResponse(let response, let data):
            let statusCode = response.statusCode()
            let body = self.getResponseBodyString(from: data)
            
            let localizedString = NSLocalizedString("global.error.notSuccessResponse",
                                                    bundle: Bundle.module,
                                                    comment: "It's error returned from remote server. Request URL: '\(response.url?.absoluteString ?? "unknown")'.")
            return String(format: localizedString, statusCode?.localizedDescription ?? "<unknown>", body)
        case .jsonDecodeError:
            return NSLocalizedString("global.error.jsonDecodeError",
                                     bundle: Bundle.module,
                                     comment: "JSON from response cannot be decoded.")
        case .unknownError:
            return NSLocalizedString("global.error.unknownError",
                                     bundle: Bundle.module,
                                     comment: "Response doesn't contains any information about request status.")
        }
    }
    
    private func getResponseBodyString(from data: Data?) -> String {
        guard let data else {
            return "<data == nil>"
        }
        
        return String(data: data, encoding: .ascii) ?? "<data != string>"
    }
}
