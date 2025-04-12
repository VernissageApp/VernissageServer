//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Foundation
import VaporTesting
import Testing
import Queues

enum AuthorizationType {
    case anonymous
    case user(userName: String, password: String, token: String? = nil)
}

enum ApiVersion {
    case none
    case v1
}

extension Application {

    func getQueueContext(queueName: QueueName) -> QueueContext {
        return QueueContext(queueName: queueName,
                            configuration: .init(),
                            application: self,
                            logger: self.logger,
                            on: self.eventLoopGroup.next())
    }
    
    func sendRequest(as authorizationType: AuthorizationType = .anonymous,
                     to path: String,
                     version: ApiVersion = .v1,
                     method: HTTPMethod,
                     headers: HTTPHeaders = .init(),
                     body: Data) async throws -> TestingHTTPResponse {

        var allHeaders = HTTPHeaders()
        let pathWithVersion = self.get(path: path, withVersion: version)
        
        switch authorizationType {
        case .user(let userName, let password, let token):

            let loginRequestDto = LoginRequestDto(userNameOrEmail: userName, password: password)
            let accessTokenDto = try await self
                .getResponse(to: "/account/login",
                             version: .v1,
                             method: .POST,
                             headers: [ Constants.twoFactorTokenHeader: token ?? "" ],
                             data: loginRequestDto,
                             decodeTo: AccessTokenDto.self)
            allHeaders.add(name: .authorization, value: "Bearer \(accessTokenDto.accessToken!)")

        break;
        default: break;
        }

        headers.forEach { header in
            allHeaders.add(name: header.name, value: header.value)
        }

        var content = ByteBufferAllocator().buffer(capacity: 0)
        content.writeData(body)
                
        var response: TestingHTTPResponse? = nil
        try await self.testing().test(method, pathWithVersion, headers: allHeaders, body: content) { res in
            response = res
        }
        
        guard let response else {
            throw SharedApplicationError.unwrap
        }
        
        return response
    }
    
    func sendRequest<T>(as authorizationType: AuthorizationType = .anonymous,
                        to path: String,
                        version: ApiVersion = .v1,
                        method: HTTPMethod, 
                        headers: HTTPHeaders = .init(),
                        body: T? = nil) async throws -> TestingHTTPResponse where T: Content {

        var allHeaders = HTTPHeaders()
        let pathWithVersion = self.get(path: path, withVersion: version)
        
        switch authorizationType {
        case .user(let userName, let password, let token):

            let loginRequestDto = LoginRequestDto(userNameOrEmail: userName, password: password)
            let accessTokenDto = try await self
                .getResponse(to: "/account/login",
                             version: .v1,
                             method: .POST,
                             headers: [ Constants.twoFactorTokenHeader: token ?? "" ],
                             data: loginRequestDto,
                             decodeTo: AccessTokenDto.self)
            allHeaders.add(name: .authorization, value: "Bearer \(accessTokenDto.accessToken!)")

        break;
        default: break;
        }

        headers.forEach { header in
            allHeaders.add(name: header.name, value: header.value)
        }

        var content = ByteBufferAllocator().buffer(capacity: 0)
        if let body = body {
            let jsonEncoder = JSONEncoder()
            jsonEncoder.dateEncodingStrategy = .iso8601
            try content.writeJSONEncodable(body, encoder: jsonEncoder)
            allHeaders.add(name: .contentType, value: "application/json")
        }
        
        var response: TestingHTTPResponse? = nil
        try await self.testing().test(method, pathWithVersion, headers: allHeaders, body: content) { res in
            response = res
        }
        
        guard let response else {
            throw SharedApplicationError.unwrap
        }
        
        return response
    }

    func sendRequest(as authorizationType: AuthorizationType = .anonymous,
                     to path: String,
                     version: ApiVersion = .v1,
                     method: HTTPMethod, 
                     headers: HTTPHeaders = .init()) async throws -> TestingHTTPResponse {

        let emptyContent: EmptyContent? = nil

        return try await sendRequest(as: authorizationType, to: path, version: version, method: method, headers: headers, body: emptyContent)
    }
    
    func sendRequest<T>(as authorizationType: AuthorizationType = .anonymous,
                        to path: String,
                        version: ApiVersion = .v1,
                        method: HTTPMethod,
                        headers: HTTPHeaders,
                        data: T) async throws -> TestingHTTPResponse where T: Content {

        return try await self.sendRequest(as: authorizationType,
                                    to: path,
                                    version: version,
                                    method: method,
                                    headers: headers,
                                    body: data)
    }
    
    func getResponse<C,T>(as authorizationType: AuthorizationType = .anonymous,
                          to path: String,
                          version: ApiVersion = .v1,
                          method: HTTPMethod = .GET, 
                          headers: HTTPHeaders = .init(), 
                          data: C? = nil,
                          decodeTo type: T.Type) async throws -> T where C: Content, T: Decodable {

        let response = try await self.sendRequest(as: authorizationType,
                                            to: path,
                                            version: version,
                                            method: method,
                                            headers: headers, 
                                            body: data)

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .customISO8601
                
        return try response.content.decode(type, using: jsonDecoder)
    }

    func getResponse<T>(as authorizationType: AuthorizationType = .anonymous,
                        to path: String,
                        version: ApiVersion = .v1,
                        method: HTTPMethod = .GET, 
                        headers: HTTPHeaders = .init(),
                        decodeTo type: T.Type) async throws -> T where T: Decodable {

        let emptyContent: EmptyContent? = nil

        return try await self.getResponse(as: authorizationType,
                                    to: path,
                                    version: version,
                                    method: method,
                                    headers: headers,
                                    data: emptyContent, 
                                    decodeTo: type)
    }
 
    func getErrorResponse<T>(as authorizationType: AuthorizationType = .anonymous,
                             to path: String,
                             version: ApiVersion = .v1,
                             method: HTTPMethod = .GET,
                             headers: HTTPHeaders = .init(),
                             data: T? = nil) async throws -> ErrorResponse where T: Content {

        let response = try await self.sendRequest(as: authorizationType,
                                            to: path,
                                            version: version,
                                            method: method,
                                            headers: headers,
                                            body: data)

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .customISO8601
        
        let errorBody = try response.content.decode(ErrorBody.self, using: jsonDecoder)
        let errorResponse = ErrorResponse(error: errorBody, status: response.status)

        return errorResponse
    }
    
    func getErrorResponse(as authorizationType: AuthorizationType = .anonymous,
                          to path: String,
                          version: ApiVersion = .v1,
                          method: HTTPMethod = .GET,
                          headers: HTTPHeaders = .init(),
                          body: Data) async throws -> ErrorResponse {

        let response = try await self.sendRequest(as: authorizationType,
                                            to: path,
                                            version: version,
                                            method: method,
                                            headers: headers,
                                            body: body)

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .customISO8601
        
        let errorBody = try response.content.decode(ErrorBody.self, using: jsonDecoder)
        let errorResponse = ErrorResponse(error: errorBody, status: response.status)

        return errorResponse
    }

    func getErrorResponse(as authorizationType: AuthorizationType = .anonymous,
                          to path: String,
                          version: ApiVersion = .v1,
                          method: HTTPMethod = .GET,
                          headers: HTTPHeaders = .init()) async throws -> ErrorResponse {

        let emptyContent: EmptyContent? = nil

        let response = try await self.sendRequest(as: authorizationType,
                                            to: path,
                                            version: version,
                                            method: method,
                                            headers: headers,
                                            body: emptyContent)

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .customISO8601

        let errorBody = try response.content.decode(ErrorBody.self, using: jsonDecoder)
        let errorResponse = ErrorResponse(error: errorBody, status: response.status)

        return errorResponse
    }
    
    private func get(path: String, withVersion version: ApiVersion) -> String {
        switch version {
        case .none:
            return path
        case .v1:
            return "/api/v1\(path)"
        }
    }
}

