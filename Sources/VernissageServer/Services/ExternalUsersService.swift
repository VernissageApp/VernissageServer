//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
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
protocol ExternalUsersServiceType: Sendable {
    /// Retrieves a local user and their associated external user record for a given OAuth user, if registered.
    ///
    /// - Parameters:
    ///   - user: The OAuth user information used to look up the registration.
    ///   - database: The database connection to use.
    /// - Returns: A tuple containing the local user (if found) and the external user record (if found).
    /// - Throws: An error if the database query fails.
    func getRegisteredExternalUser(user: OAuthUser, on database: Database) async throws -> (User?, ExternalUser?)

    /// Generates the OAuth 2.0 authorization redirect URL for the specified authentication client and base address.
    ///
    /// - Parameters:
    ///   - authClient: The authentication client containing configuration details.
    ///   - baseAddress: The base address of the application for the redirect URI.
    /// - Returns: The redirect URL as a string.
    /// - Throws: An error if URL generation fails or required parameters are missing.
    func getRedirectLocation(authClient: AuthClient, baseAddress: String) throws -> String

    /// Constructs an OAuth 2.0 token request for the specified authentication client, base address, and authorization code.
    ///
    /// - Parameters:
    ///   - authClient: The authentication client containing configuration details.
    ///   - baseAddress: The base address of the application for the redirect URI.
    ///   - code: The authorization code received from the OAuth flow.
    /// - Returns: The constructed OAuth token request object.
    func getOauthRequest(authClient: AuthClient, baseAddress: String, code: String) -> OAuthRequest
}

/// A service for managing users created by OpenId Connect.
final class ExternalUsersService: ExternalUsersServiceType {

    public func getRegisteredExternalUser(user: OAuthUser, on database: Database) async throws -> (User?, ExternalUser?) {
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
        let host = "https://appleid.apple.com/auth/authorize"
        
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
        let oauthRequest = OAuthRequest(url: "https://appleid.apple.com/auth/token",
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
