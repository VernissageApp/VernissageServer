//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Errors registered in application.
final class ErrorItem: Model, @unchecked Sendable {
    static let schema: String = "ErrorItems"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "source")
    var source: ErrorItemSource
    
    @Field(key: "code")
    var code: String
    
    @Field(key: "message")
    var message: String
        
    @Field(key: "exception")
    var exception: String?
    
    @Field(key: "userAgent")
    var userAgent: String?

    @Field(key: "clientVersion")
    var clientVersion: String?

    @Field(key: "serverVersion")
    var serverVersion: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, source: ErrorItemSource = .server, code: String, message: String, exception: String?, userAgent: String?, clientVersion: String?, serverVersion: String?) {
        self.init()

        self.id = id
        self.source = source
        self.code = code
        self.message = message
        self.exception = exception
        self.userAgent = userAgent
        self.clientVersion = clientVersion
        self.serverVersion = serverVersion
    }
}

/// Allows `ErrorItem` to be encoded to and decoded from HTTP messages.
extension ErrorItem: Content { }
