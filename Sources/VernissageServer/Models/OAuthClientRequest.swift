//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

/// OAuth authorization requests.
final class OAuthClientRequest: Model, @unchecked Sendable {
    static let schema = "OAuthClientRequests"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    /// Dynamic client used to user authorize flow.
    @Parent(key: "authDynamicClientId")
    var authDynamicClient: AuthDynamicClient
    
    /// Dynamic client used to user authorize flow.
    @Parent(key: "userId")
    var user: User
    
    @Field(key: "csrfToken")
    var csrfToken: String

    @Field(key: "redirectUri")
    var redirectUri: String

    @Field(key: "scope")
    var scope: String
    
    @Field(key: "state")
    var state: String
    
    @Field(key: "nonce")
    var nonce: String
    
    @Field(key: "code")
    var code: String?

    @Timestamp(key: "codeGeneratedAt", on: .none)
    var codeGeneratedAt: Date?
    
    @Timestamp(key: "authorizedAt", on: .none)
    var authorizedAt: Date?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    convenience init(
        id: Int64,
        authDynamicClientId: Int64,
        userId: Int64,
        csrfToken: String,
        redirectUri: String,
        scope: String,
        state: String,
        nonce: String
    ) {
        self.init()

        self.id = id
        self.$authDynamicClient.id = authDynamicClientId
        self.$user.id = userId
        self.csrfToken = csrfToken
        self.redirectUri = redirectUri
        self.scope = scope
        self.state = state
        self.nonce = nonce
        self.authorizedAt = nil
        self.createdAt = nil
        self.updatedAt = nil
    }
}

/// Allows `OAuthClientRequest` to be encoded to and decoded from HTTP messages.
extension OAuthClientRequest: Content { }

extension OAuthClientRequest {
    var scopesArray: [String] {
        return self.scope.components(separatedBy: " ")
    }
}
