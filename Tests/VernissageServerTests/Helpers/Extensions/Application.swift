//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Foundation
import XCTest
import XCTVapor
import Queues

enum AuthorizationType {
    case anonymous
    case user(userName: String, password: String)
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
                     body: Data) throws -> XCTHTTPResponse {

        var allHeaders = HTTPHeaders()
        let pathWithVersion = self.get(path: path, withVersion: version)
        
        switch authorizationType {
        case .user(let userName, let password):

            let loginRequestDto = LoginRequestDto(userNameOrEmail: userName, password: password)
            let accessTokenDto = try SharedApplication.application()
                .getResponse(to: "/account/login",
                             version: .v1,
                             method: .POST,
                             data: loginRequestDto,
                             decodeTo: AccessTokenDto.self)
            allHeaders.add(name: .authorization, value: "Bearer \(accessTokenDto.accessToken)")

        break;
        default: break;
        }

        headers.forEach { header in
            allHeaders.add(name: header.name, value: header.value)
        }

        var content = ByteBufferAllocator().buffer(capacity: 0)
        content.writeData(body)
                
        var response: XCTHTTPResponse? = nil
        try SharedApplication.testable().test(method, pathWithVersion, headers: allHeaders, body: content) { res in
            response = res
        }
        
        return response!
    }
    
    func sendRequest<T>(as authorizationType: AuthorizationType = .anonymous,
                        to path: String,
                        version: ApiVersion = .v1,
                        method: HTTPMethod, 
                        headers: HTTPHeaders = .init(),
                        body: T? = nil) throws -> XCTHTTPResponse where T: Content {

        var allHeaders = HTTPHeaders()
        let pathWithVersion = self.get(path: path, withVersion: version)
        
        switch authorizationType {
        case .user(let userName, let password):

            let loginRequestDto = LoginRequestDto(userNameOrEmail: userName, password: password)
            let accessTokenDto = try SharedApplication.application()
                .getResponse(to: "/account/login",
                             version: .v1,
                             method: .POST,
                             data: loginRequestDto,
                             decodeTo: AccessTokenDto.self)
            allHeaders.add(name: .authorization, value: "Bearer \(accessTokenDto.accessToken)")

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
        
        var response: XCTHTTPResponse? = nil
        try SharedApplication.testable().test(method, pathWithVersion, headers: allHeaders, body: content) { res in
            response = res
        }
        
        return response!
    }

    func sendRequest(as authorizationType: AuthorizationType = .anonymous,
                     to path: String,
                     version: ApiVersion = .v1,
                     method: HTTPMethod, 
                     headers: HTTPHeaders = .init()) throws -> XCTHTTPResponse {

        let emptyContent: EmptyContent? = nil

        return try sendRequest(as: authorizationType, to: path, version: version, method: method, headers: headers, body: emptyContent)
    }
    
    func sendRequest<T>(as authorizationType: AuthorizationType = .anonymous,
                        to path: String,
                        version: ApiVersion = .v1,
                        method: HTTPMethod,
                        headers: HTTPHeaders,
                        data: T) throws -> XCTHTTPResponse where T: Content {

        return try self.sendRequest(as: authorizationType,
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
                          decodeTo type: T.Type) throws -> T where C: Content, T: Decodable {

        let response = try self.sendRequest(as: authorizationType,
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
                        decodeTo type: T.Type) throws -> T where T: Decodable {

        let emptyContent: EmptyContent? = nil

        return try self.getResponse(as: authorizationType,
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
                             data: T? = nil) throws -> ErrorResponse where T: Content {

        let response = try self.sendRequest(as: authorizationType,
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
                          body: Data) throws -> ErrorResponse {

        let response = try self.sendRequest(as: authorizationType,
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
                          headers: HTTPHeaders = .init()) throws -> ErrorResponse {

        let emptyContent: EmptyContent? = nil

        let response = try self.sendRequest(as: authorizationType,
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

