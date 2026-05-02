//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private enum ConnectionErrorClassifier {
    static let connectionErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .networkConnectionLost,
        .dnsLookupFailed,
        .notConnectedToInternet,
        .resourceUnavailable,
        .cannotLoadFromNetwork
    ]

    static let connectionPosixCodes: Set<Int32> = [
        ECONNREFUSED,
        ECONNRESET,
        ETIMEDOUT,
        EHOSTUNREACH,
        ENETUNREACH,
        ENETDOWN,
        ENOTCONN
    ]

    static let connectionErrorCodeRawValues: Set<Int> = Set(Self.connectionErrorCodes.map(\.rawValue))
    static let unknownConnectionErrorHints: [String] = [
        "failed to connect",
        "couldn't connect to server",
        "could not connect to server",
        "connection refused",
        "connection reset",
        "could not resolve host",
        "couldn't resolve host",
        "ssl certificate problem",
        "no alternative certificate subject name matches target host name",
        "unable to get local issuer certificate",
        "http/2 stream",
        "internal_error"
    ]

    static func isConnectionError(_ error: Error) -> Bool {
        if let urlError = error as? URLError, connectionErrorCodes.contains(urlError.code) {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           connectionErrorCodeRawValues.contains(nsError.code) {
            return true
        }

        if nsError.domain == NSURLErrorDomain,
           nsError.code == URLError.unknown.rawValue {
            let description = ((nsError.userInfo[NSLocalizedDescriptionKey] as? String) ?? nsError.localizedDescription)
                .lowercased()

            if unknownConnectionErrorHints.contains(where: { description.contains($0) }) {
                return true
            }
        }

        if nsError.domain == NSPOSIXErrorDomain,
           connectionPosixCodes.contains(Int32(nsError.code)) {
            return true
        }

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isConnectionError(underlyingError)
        }

        return false
    }
}

extension Error {
    var isConnectionError: Bool {
        ConnectionErrorClassifier.isConnectionError(self)
    }
}
