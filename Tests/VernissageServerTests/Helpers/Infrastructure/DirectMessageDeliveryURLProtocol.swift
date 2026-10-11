//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Synchronization

/// Captures real signed requests without external network access. State is protected across URLSession callbacks.
final class DirectMessageDeliveryURLProtocol: URLProtocol {
    private struct State {
        var requests: [URLRequest] = []
        var failOnce: Set<String> = []
    }

    private static let state = Mutex(State())

    static var requests: [URLRequest] {
        state.withLock { $0.requests }
    }

    static func session(failOnce: Set<String> = []) -> URLSession {
        state.withLock { $0 = State(failOnce: failOnce) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Self.self]

        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var captured = request

        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open()

            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)

            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)

                guard count > 0 else {
                    break
                }

                data.append(contentsOf: buffer.prefix(count))
            }

            captured.httpBody = data
        }

        let status = Self.state.withLock { state in
            state.requests.append(captured)

            return state.failOnce.remove(captured.url?.absoluteString ?? "") == nil ? 202 : 503
        }

        guard let url = captured.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))

            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}
