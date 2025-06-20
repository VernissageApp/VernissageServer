//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createOAuthClientRequest(authDynamicClientId: Int64,
                                  userId: Int64,
                                  csrfToken: String,
                                  redirectUri: String,
                                  scope: String,
                                  state: String,
                                  nonce: String) async throws -> OAuthClientRequest {
        let id =  await ApplicationManager.shared.generateId()
        let oAuthClientRequest = OAuthClientRequest(id: id,
                                                   authDynamicClientId: authDynamicClientId,
                                                   userId: userId,
                                                   csrfToken: csrfToken,
                                                   redirectUri: redirectUri,
                                                   scope: scope,
                                                   state: state,
                                                   nonce: nonce)
        
        // Save client metadata in the database.
        try await oAuthClientRequest.save(on: self.db)
        return oAuthClientRequest
    }

    func genereteOAuthClientRequestCode(oAuthClientRequest: OAuthClientRequest, codeGeneratedAt: Date? = nil) async throws {
        let generatedCode = String.createRandomString(length: 32)
        oAuthClientRequest.code = generatedCode
        oAuthClientRequest.codeGeneratedAt = codeGeneratedAt ?? Date()
        
        try await oAuthClientRequest.save(on: self.db)
    }
    
    func authorizeOAuthClientRequest(oAuthClientRequest: OAuthClientRequest) async throws {
        oAuthClientRequest.authorizedAt = Date()
        try await oAuthClientRequest.save(on: self.db)
    }
}
