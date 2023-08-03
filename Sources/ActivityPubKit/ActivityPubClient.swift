//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class ActivityPubClient {
    let urlSession: URLSession
    let baseURL: URL?
    
    public init(baseURL: URL? = nil, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }
    
    static func request(for baseURL: URL, target: TargetType, timeoutInterval: Double? = nil) throws -> URLRequest {

        var urlComponents = self.createUrlComponents(for: baseURL, target: target)
        urlComponents?.queryItems = target.queryItems?.map { URLQueryItem(name: $0.0, value: $0.1) }

        guard let url = urlComponents?.url else { throw NetworkingError.cannotCreateUrlRequest }

        var request = URLRequest(url: url)

        if let timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }

        target.headers?.forEach { header in
            request.setValue(header.1, forHTTPHeaderField: header.0)
        }

        request.httpMethod = target.method.rawValue
        request.httpBody = target.httpBody

        return request
    }
    
    public func downloadJson<T>(_ type: T.Type, request: URLRequest) async throws -> T where T: Decodable {
        let (data, response) = try await urlSession.asyncData(for: request)
        guard (response as? HTTPURLResponse)?.status?.responseType == .success else {
            throw NetworkError.notSuccessResponse(response)
        }

        #if DEBUG
            do {
                return try JSONDecoder().decode(type, from: data)
            } catch {
                let json = String(data: data, encoding: .utf8)!
                print(json)

                throw error
            }
        #else
            return try JSONDecoder().decode(type, from: data)
        #endif
    }
    
    private static func createUrlComponents(for baseURL: URL, target: TargetType) -> URLComponents? {
        if target.path.isEmpty {
            return URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        }
        
        return URLComponents(url: baseURL.appendingPathComponent(target.path), resolvingAgainstBaseURL: false)
    }
}
