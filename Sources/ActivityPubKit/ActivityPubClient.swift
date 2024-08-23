//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class ActivityPubClient {
    let urlSession: URLSession
    let privatePemKey: String?
    let userAgent: String?
    let host: String?
    
    public init(privatePemKey: String? = nil, userAgent: String? = nil, host: String? = nil, urlSession: URLSession = .shared) {
        self.privatePemKey = privatePemKey
        self.urlSession = urlSession
        self.userAgent = userAgent
        self.host = host
    }
    
    static func request(for baseURL: URL, target: TargetType, timeoutInterval: Double? = nil) throws -> URLRequest {
        var urlComponents = self.createUrlComponents(for: baseURL)
        urlComponents?.queryItems = target.queryItems?.map { URLQueryItem(name: $0.0, value: $0.1) }

        guard let url = urlComponents?.url else { throw NetworkingError.cannotCreateUrlRequest }

        var request = URLRequest(url: url)

        if let timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }

        target.headers?.forEach { header in
            request.setValue(header.1, forHTTPHeaderField: header.0.rawValue)
        }

        request.httpMethod = target.method.rawValue
        request.httpBody = target.httpBody

        return request
    }
    
    static func request(forFullUrl fullUrl: URL, target: TargetType, timeoutInterval: Double? = nil) throws -> URLRequest {
        var request = URLRequest(url: fullUrl)

        if let timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }

        target.headers?.forEach { header in
            request.setValue(header.1, forHTTPHeaderField: header.0.rawValue)
        }

        request.httpMethod = target.method.rawValue
        request.httpBody = target.httpBody

        return request
    }
    
    public func downloadJson<T>(_ type: T.Type, request: URLRequest) async throws -> T where T: Decodable {
        let (data, response) = try await urlSession.asyncData(for: request)
        guard (response as? HTTPURLResponse)?.status?.responseType == .success else {
            throw NetworkError.notSuccessResponse(response, data)
        }

        #if DEBUG
            do {
                return try JSONDecoder().decode(type, from: data)
            } catch let DecodingError.dataCorrupted(context) {
                print(context)

                throw NetworkError.jsonDecodeError
            } catch let DecodingError.keyNotFound(key, context) {
                print("Key '\(key)' not found:", context.debugDescription)
                print("codingPath:", context.codingPath)

                throw NetworkError.jsonDecodeError
            } catch let DecodingError.valueNotFound(value, context) {
                print("Value '\(value)' not found:", context.debugDescription)
                print("codingPath:", context.codingPath)

                throw NetworkError.jsonDecodeError
            } catch let DecodingError.typeMismatch(type, context)  {
                print("Type '\(type)' mismatch:", context.debugDescription)
                print("codingPath:", context.codingPath)

                throw NetworkError.jsonDecodeError
            } catch {
                let json = String(data: data, encoding: .utf8)!
                print(json)

                throw error
            }
        #else
            return try JSONDecoder().decode(type, from: data)
        #endif
    }
    
    public func downloadBody(request: URLRequest) async throws -> String? {
        let (data, response) = try await urlSession.asyncData(for: request)
        
        let responseBody = String(data: data, encoding: .ascii)
        
        #if DEBUG
            if let responseBody {
                print(responseBody)
            }
        #endif
        
        guard (response as? HTTPURLResponse)?.status?.responseType == .success else {
            throw NetworkError.notSuccessResponse(response, data)
        }
        
        return responseBody
    }
    
    private static func createUrlComponents(for baseURL: URL) -> URLComponents? {
        return URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    }
}
