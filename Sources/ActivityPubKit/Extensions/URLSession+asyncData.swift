import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum URLSessionAsyncErrors: Error {
    case invalidUrlResponse, missingResponseData
}

public extension URLSession {
    func asyncData(from url: URL) async throws -> (Data, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: url) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let response = response as? HTTPURLResponse else {
                    continuation.resume(throwing: URLSessionAsyncErrors.invalidUrlResponse)
                    return
                }
                guard let data = data else {
                    continuation.resume(throwing: URLSessionAsyncErrors.missingResponseData)
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
    
    func asyncData(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let response = response as? HTTPURLResponse else {
                    continuation.resume(throwing: URLSessionAsyncErrors.invalidUrlResponse)
                    return
                }
                guard let data = data else {
                    continuation.resume(throwing: URLSessionAsyncErrors.missingResponseData)
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
}
