//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct ExternalUsersServiceTypeKey: StorageKey {
        typealias Value = ExternalUsersServiceType
    }

    var externalUsersService: ExternalUsersServiceType {
        get {
            self.application.storage[ExternalUsersServiceTypeKey.self] ?? ExternalUsersService()
        }
        nonmutating set {
            self.application.storage[ExternalUsersServiceTypeKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ExternalUsersServiceType {
    func getRegisteredExternalUser(on database: Database, user: OAuthUser) async throws -> (User?, ExternalUser?)
    func getRedirectLocation(authClient: AuthClient, baseAddress: String) throws -> String
    func getOauthRequest(authClient: AuthClient, baseAddress: String, code: String) -> OAuthRequest
}

final class ExternalUsersService: ExternalUsersServiceType {

    public func getRegisteredExternalUser(on database: Database, user: OAuthUser) async throws -> (User?, ExternalUser?) {
        let externalUser = try await ExternalUser.query(on: database).with(\.$user).filter(\.$externalId == user.uniqueId).first()
            
        if let externalUser = externalUser {
            return (externalUser.user, externalUser)
        }
        
        let emailNormalized = user.email.uppercased()
        let user = try await User.query(on: database).filter(\.$emailNormalized == emailNormalized).first()
        if let user = user {
            return (user, nil)
        }
        
        return (nil, nil)
    }
    
    public func getRedirectLocation(authClient: AuthClient, baseAddress: String) throws -> String {
        switch authClient.type {
        case .apple:
            return try self.createAppleUrl(baseAddress: baseAddress, uri: authClient.uri, clientId: authClient.clientId)
        case .google:
            return try self.createGoogleUrl(baseAddress: baseAddress, uri: authClient.uri, clientId: authClient.clientId)
        case .microsoft:
            return try self.createMicrosoftUrl(baseAddress: baseAddress,
                                               uri: authClient.uri,
                                               tenantId: authClient.tenantId,
                                               clientId: authClient.clientId)
        }
    }
    
    public func getOauthRequest(authClient: AuthClient, baseAddress: String, code: String) -> OAuthRequest {
        switch authClient.type {
        case .apple:
            return self.getAppleOauthRequest(baseAddress: baseAddress,
                                             uri: authClient.uri,
                                             clientId: authClient.clientId,
                                             clientSecret: authClient.clientSecret,
                                             code: code)
        case .google:
            return self.getGoogleOauthRequest(baseAddress: baseAddress,
                                              uri: authClient.uri,
                                              clientId: authClient.clientId,
                                              clientSecret: authClient.clientSecret,
                                              code: code)
        case .microsoft:
            return self.getMicrosoftOauthRequest(baseAddress: baseAddress,
                                                 uri: authClient.uri,
                                                 tenantId: authClient.tenantId ?? "",
                                                 clientId: authClient.clientId,
                                                 clientSecret: authClient.clientSecret,
                                                 code: code)
        }
    }
    
    private func createAppleUrl(baseAddress: String, uri: String, clientId: String) throws -> String {
        let host = "https://accounts.google.com/o/oauth2/v2/auth"
        
        let urlEncoder = URLEncodedFormEncoder()
        let scope = try urlEncoder.encode("openid profile email")
        let responseType = try urlEncoder.encode("code")
        let clientId = try urlEncoder.encode(clientId)
        let redirectUri = try urlEncoder.encode("\(baseAddress)/identity/callback/\(uri)")
        let state = try urlEncoder.encode(self.generateState())
        let nonce = try urlEncoder.encode(self.generateNonce())
        
        let location = "\(host)?" +
            "scope=\(scope)" +
            "&response_type=\(responseType)" +
            "&client_id=\(clientId)" +
            "&redirect_uri=\(redirectUri)" +
            "&state=\(state)" +
            "&nonce=\(nonce)"
        
        return location
    }
        
    private func createGoogleUrl(baseAddress: String, uri: String, clientId: String) throws -> String {
        let host = "https://accounts.google.com/o/oauth2/v2/auth"
        
        let urlEncoder = URLEncodedFormEncoder()
        let scope = try urlEncoder.encode("openid profile email")
        let responseType = try urlEncoder.encode("code")
        let clientId = try urlEncoder.encode(clientId)
        let redirectUri = try urlEncoder.encode("\(baseAddress)/identity/callback/\(uri)")
        let state = try urlEncoder.encode(self.generateState())
        let nonce = try urlEncoder.encode(self.generateNonce())
        
        let location = "\(host)?" +
            "scope=\(scope)" +
            "&response_type=\(responseType)" +
            "&client_id=\(clientId)" +
            "&redirect_uri=\(redirectUri)" +
            "&state=\(state)" +
            "&nonce=\(nonce)"
        
        return location
    }

    private func createMicrosoftUrl(baseAddress: String, uri: String, tenantId: String?, clientId: String) throws -> String {
        let host = "https://login.microsoftonline.com/\(tenantId ?? "unknown")/oauth2/v2.0/authorize"
        
        let urlEncoder = URLEncodedFormEncoder()
        let scope = try urlEncoder.encode("openid profile email")
        let responseType = try urlEncoder.encode("code")
        let clientId = try urlEncoder.encode(clientId)
        let redirectUri = try urlEncoder.encode("\(baseAddress)/identity/callback/\(uri)")
        let state = try urlEncoder.encode(self.generateState())
        let nonce = try urlEncoder.encode(self.generateNonce())
        
        let location = "\(host)?" +
            "scope=\(scope)" +
            "&response_type=\(responseType)" +
            "&client_id=\(clientId)" +
            "&redirect_uri=\(redirectUri)" +
            "&state=\(state)" +
            "&nonce=\(nonce)"
        
        return location
    }
    
    private func getAppleOauthRequest(baseAddress: String,
                                      uri: String,
                                      clientId: String,
                                      clientSecret: String,
                                      code: String) -> OAuthRequest {
        let oauthRequest = OAuthRequest(url: "https://oauth2.googleapis.com/token",
                                        code: code,
                                        clientId: clientId,
                                        clientSecret: clientSecret,
                                        redirectUri: "\(baseAddress)/identity/callback/\(uri)",
                                        grantType: "authorization_code")
        
        return oauthRequest
    }

    private func getGoogleOauthRequest(baseAddress: String,
                                       uri: String,
                                       clientId: String,
                                       clientSecret: String,
                                       code: String) -> OAuthRequest {
        let oauthRequest = OAuthRequest(url: "https://oauth2.googleapis.com/token",
                                        code: code,
                                        clientId: clientId,
                                        clientSecret: clientSecret,
                                        redirectUri: "\(baseAddress)/identity/callback/\(uri)",
                                        grantType: "authorization_code")
        
        return oauthRequest
    }

    private func getMicrosoftOauthRequest(baseAddress: String,
                                          uri: String,
                                          tenantId: String,
                                          clientId: String,
                                          clientSecret: String,
                                          code: String) -> OAuthRequest {
        let oauthRequest = OAuthRequest(url: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token",
                                        code: code,
                                        clientId: clientId,
                                        clientSecret: clientSecret,
                                        redirectUri: "\(baseAddress)/identity/callback/\(uri)",
                                        grantType: "authorization_code")
        
        return oauthRequest
    }
    
    private func generateState() -> String {
        let uuid = UUID().uuidString.lowercased()
        return Data(uuid.utf8).base64EncodedString()
    }
    
    private func generateNonce() -> String {
        let uuid = UUID().uuidString.lowercased()
        return Data(uuid.utf8).base64EncodedString()
    }
}
