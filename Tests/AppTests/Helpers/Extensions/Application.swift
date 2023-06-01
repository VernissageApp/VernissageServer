//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import Foundation
import XCTest
import XCTVapor

enum AuthorizationType {
    case anonymous
    case user(userName: String, password: String)
}

extension Application {

    func sendRequest<T>(as authorizationType: AuthorizationType = .anonymous,
                        to path: String, 
                        method: HTTPMethod, 
                        headers: HTTPHeaders = .init(),
                        body: T? = nil) throws -> XCTHTTPResponse where T: Content {

        var allHeaders = HTTPHeaders()

        switch authorizationType {
        case .user(let userName, let password):

            let loginRequestDto = LoginRequestDto(userNameOrEmail: userName, password: password)
            let accessTokenDto = try SharedApplication.application()
                .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)
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
        try SharedApplication.testable().test(method, path, headers: allHeaders, body: content) { res in
            response = res
        }
        
        return response!
    }

    func sendRequest(as authorizationType: AuthorizationType = .anonymous,
                     to path: String, 
                     method: HTTPMethod, 
                     headers: HTTPHeaders = .init()) throws -> XCTHTTPResponse {

        let emptyContent: EmptyContent? = nil

        return try sendRequest(as: authorizationType, to: path, method: method, headers: headers, body: emptyContent)
    }
    
    func sendRequest<T>(as authorizationType: AuthorizationType = .anonymous,
                        to path: String,
                        method: HTTPMethod,
                        headers: HTTPHeaders,
                        data: T) throws where T: Content {

        _ = try self.sendRequest(as: authorizationType, to: path, method: method, headers: headers, body: data)
    }
    
    func getResponse<C,T>(as authorizationType: AuthorizationType = .anonymous,
                          to path: String,
                          method: HTTPMethod = .GET, 
                          headers: HTTPHeaders = .init(), 
                          data: C? = nil,
                          decodeTo type: T.Type) throws -> T where C: Content, T: Decodable {

        let response = try self.sendRequest(as: authorizationType, 
                                            to: path, 
                                            method: method,
                                            headers: headers, 
                                            body: data)

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        
        return try response.content.decode(type, using: jsonDecoder)
    }

    func getResponse<T>(as authorizationType: AuthorizationType = .anonymous,
                        to path: String,
                        method: HTTPMethod = .GET, 
                        headers: HTTPHeaders = .init(),
                        decodeTo type: T.Type) throws -> T where T: Decodable {

        let emptyContent: EmptyContent? = nil

        return try self.getResponse(as: authorizationType,
                                    to: path, 
                                    method: method,
                                    headers: headers,
                                    data: emptyContent, 
                                    decodeTo: type)
    }
 
    func getErrorResponse<T>(as authorizationType: AuthorizationType = .anonymous,
                          to path: String,
                          method: HTTPMethod = .GET,
                          headers: HTTPHeaders = .init(),
                          data: T? = nil) throws -> ErrorResponse where T: Content {

        let response = try self.sendRequest(as: authorizationType,
                                            to: path,
                                            method: method,
                                            headers: headers,
                                            body: data)

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        
        let errorBody = try response.content.decode(ErrorBody.self, using: jsonDecoder)
        let errorResponse = ErrorResponse(error: errorBody, status: response.status)

        return errorResponse
    }

    func getErrorResponse(as authorizationType: AuthorizationType = .anonymous,
                          to path: String,
                          method: HTTPMethod = .GET,
                          headers: HTTPHeaders = .init()) throws -> ErrorResponse {

        let emptyContent: EmptyContent? = nil

        let response = try self.sendRequest(as: authorizationType,
                                            to: path,
                                            method: method,
                                            headers: headers,
                                            body: emptyContent)

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601

        let errorBody = try response.content.decode(ErrorBody.self, using: jsonDecoder)
        let errorResponse = ErrorResponse(error: errorBody, status: response.status)

        return errorResponse
    }
}

