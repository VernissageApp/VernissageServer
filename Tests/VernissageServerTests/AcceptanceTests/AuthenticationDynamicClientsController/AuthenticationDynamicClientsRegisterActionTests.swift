//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("AuthenticationDynamicClients (POST /auth-dynamic-clients)", .serialized, .tags(.authDynamicClients))
    struct AuthenticationDynamicClientsRegisterActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("OAuth dynamic client should be registered with minimum required metadata")
        func oAuthDynamicClientShouldBeRegisteredWithMinimumRequiredMetadata() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://localhost.com/callback"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code])
            
            // Act.
            let createdAuthDtoDto = try await application.getResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientResponseDto.self
            )
            
            // Assert.
            #expect(createdAuthDtoDto.clientId.count > 0, "Auth client id wasn't created.")
        }
        
        @Test("OAuth dynamic client should be registered with all metadata")
        func oAuthDynamicClientShouldBeRegisteredWithAllMetadata() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://localhost.com/callback"],
                                                                              tokenEndpointAuthMethod: OAuthTokenEndpointAuthMethodDto.none,
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              clientName: "client name",
                                                                              clientUri: "https://client.uri",
                                                                              logoUri: "https://logo.uri",
                                                                              scope: "code token",
                                                                              contacts: ["admin@example.com", "mod@example.com"],
                                                                              tosUri: "https://tos.uri",
                                                                              policyUri: "https://policy.uri",
                                                                              jwksUri: "https://jwks.uri",
                                                                              jwks: "jwks",
                                                                              softwareId: "software id",
                                                                              softwareVersion: "software version")
            
            // Act.
            let createdAuthDtoDto = try await application.getResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientResponseDto.self
            )
            
            // Assert.
            #expect(createdAuthDtoDto.clientId.count > 0, "Auth client id wasn't created.")
            #expect(createdAuthDtoDto.redirectUris.contains(where: { $0 ==  "https://localhost.com/callback" }), "Redirect Uris should be saved correctly.")
            #expect(createdAuthDtoDto.tokenEndpointAuthMethod == OAuthTokenEndpointAuthMethodDto.none, "Token endpoint auth method should be saved correctly.")
            #expect(createdAuthDtoDto.grantTypes.contains(where: { $0 == OAuthGrantTypeDto.authorizationCode }), "Grant types should be saved correctly.")
            #expect(createdAuthDtoDto.responseTypes.contains(where: { $0 == OAuthResponseTypeDto.code }), "Response types should be saved correctly.")
            #expect(createdAuthDtoDto.clientName == "client name", "Client name should be saved correctly.")
            #expect(createdAuthDtoDto.clientUri == "https://client.uri", "Client uri should be saved correctly.")
            #expect(createdAuthDtoDto.logoUri == "https://logo.uri", "Logo uri should be saved correctly.")
            #expect(createdAuthDtoDto.scope == "code token", "Scope should be saved correctly.")
            #expect(createdAuthDtoDto.contacts?.contains(where: { $0 == "admin@example.com" }) == true, "Contacts should be saved correctly.")
            #expect(createdAuthDtoDto.contacts?.contains(where: { $0 == "mod@example.com" }) == true, "Contacts should be saved correctly.")
            #expect(createdAuthDtoDto.tosUri  == "https://tos.uri", "Tos uri should be saved correctly.")
            #expect(createdAuthDtoDto.policyUri  == "https://policy.uri", "Policy uri should be saved correctly.")
            #expect(createdAuthDtoDto.jwksUri  == "https://jwks.uri", "Jwks uri should be saved correctly.")
            #expect(createdAuthDtoDto.jwks  == "jwks", "Jwks should be saved correctly.")
            #expect(createdAuthDtoDto.softwareId  == "software id", "Software id should be saved correctly.")
            #expect(createdAuthDtoDto.softwareVersion  == "software version", "Software version should be saved correctly.")
        }
        
        @Test("OAuth dynamic client should be registered for client credentials grant type")
        func oAuthDynamicClientShouldBeRegisteredForClientCredentialsGrantType() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "borisglino")
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              tokenEndpointAuthMethod: .clientSecretPost,
                                                                              grantTypes: [OAuthGrantTypeDto.clientCredentials],
                                                                              responseTypes: [])
                        
            // Act.
            let createdAuthDtoDto = try await application.getResponse(
                as: .user(userName: "borisglino", password: "p@ssword"),
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientResponseDto.self
            )
            
            // Assert.
            #expect(createdAuthDtoDto.clientId.count > 0, "Auth client id wasn't created.")
            #expect(createdAuthDtoDto.clientSecret?.isEmpty == false, "Auth client secret wasn't created.")
        }
        
        @Test("OAuth dynamic client should not be registered without redirect url")
        func oAuthDynamicClientShouldNotBeRegisteredWithoutRedirectUrl() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: [],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code])
                        
            // Act.
            let errorResponse = try await application.getResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientErrorDto.self
            )
            
            // Assert.
            #expect(errorResponse.errorDescription == "Redirect URI is required.", "Error description should be correct.")
            #expect(errorResponse.error == .invalidClientMetadata, "Error code should be equal 'invalid_client_metadata'.")
        }
        
        @Test("OAuth dynamic client should be registered with default grant types")
        func oAuthDynamicClientShouldBeRegisteredWithDefaultGrantTypes() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://localhost.com/callback"],
                                                                              grantTypes: [],
                                                                              responseTypes: [OAuthResponseTypeDto.code])
            
            // Act.
            let createdAuthDtoDto = try await application.getResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientResponseDto.self
            )
            
            // Assert.
            #expect(createdAuthDtoDto.grantTypes.contains(where: { $0 == OAuthGrantTypeDto.authorizationCode }), "Auth client not created.")
        }
        
        @Test("OAuth dynamic client should be registered with default response types")
        func oAuthDynamicClientShouldBeRegisteredWithDefaultResponseTypes() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://localhost.com/callback"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [])
            
            // Act.
            let createdAuthDtoDto = try await application.getResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientResponseDto.self
            )
            
            // Assert.
            #expect(createdAuthDtoDto.responseTypes.contains(where: { $0 == OAuthResponseTypeDto.code }), "Auth client not created.")
        }
        
        @Test("OAuth dynamic client should not be registered with too long client_name")
        func oAuthDynamicClientShouldNotBeRegisteredWithTooLongClientName() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              clientName: String.createRandomString(length: 201))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("client_name") == "is not null and is greater than maximum of 200 character(s)")
        }
        
        @Test("OAuth dynamic client should not be registered with too long scope")
        func oAuthDynamicClientShouldNotBeRegisteredWithTooLongScope() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              scope: String.createRandomString(length: 101))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("scope") == "is not null and is greater than maximum of 100 character(s)")
        }
        
        @Test("OAuth dynamic client should not be registered with too long software_id")
        func oAuthDynamicClientShouldNotBeRegisteredWithTooLongSoftwareId() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              softwareId: String.createRandomString(length: 101))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("software_id") == "is not null and is greater than maximum of 100 character(s)")
        }
        
        @Test("OAuth dynamic client should not be registered with too long software_version")
        func oAuthDynamicClientShouldNotBeRegisteredWithTooLongSoftwareVersion() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              softwareVersion: String.createRandomString(length: 101))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("software_version") == "is not null and is greater than maximum of 100 character(s)")
        }
        
        @Test("OAuth dynamic client should not be registered with too long client_uri")
        func oAuthDynamicClientShouldNotBeRegisteredWithTooLongClientUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              clientUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("client_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("OAuth dynamic client should not be registered with incorrect client_uri")
        func oAuthDynamicClientShouldNotBeRegisteredWithIncorrectClientUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              clientUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("client_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("OAuth dynamic client should not be registered with too long logo_uri")
        func oAuthDynamicClientShouldNotBeRegisteredWithTooLongLogoUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              logoUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("logo_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("OAuth dynamic client should not be registered with incorrect logo_uri")
        func oAuthDynamicClientShouldNotBeRegisteredWithIncorrectLogoUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              logoUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("logo_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("OAuth dynamic client should not be registered with too long tos_uri")
        func oAuthDynamicClientShouldNotBeRegisteredWithTooLongTosUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              tosUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("tos_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("OAuth dynamic client should not be registered with incorrect tos_uri")
        func oAuthDynamicClientShouldNotBeRegisteredWithIncorrectTosUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              tosUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("tos_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("OAuth dynamic client should not be registered with too long policy_uri")
        func oAuthDynamicClientShouldNotBeRegisteredWithTooLongPolicyUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              policyUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("policy_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("OAuth dynamic client should not be registered with incorrect policy_uri")
        func oAuthDynamicClientShouldNotBeRegisteredWithIncorrectPolicyUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              policyUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("policy_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("OAuth dynamic client should not be registered with too long jwks_uri")
        func oAuthDynamicClientShouldNotBeRegisteredWithTooLongJwksUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              jwksUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("jwks_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("OAuth dynamic client should not be registered with incorrect jwks_uri")
        func oAuthDynamicClientShouldNotBeRegisteredWithIncorrectJwksUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              jwksUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("jwks_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("OAuth dynamic client should not be registered for implicit grant type")
        func oAuthDynamicClientShouldNotBeRegisteredForImplicitGrantType() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [])
                        
            // Act.
            let errorResponse = try await application.getResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientErrorDto.self
            )
            
            // Assert.
            #expect(errorResponse.errorDescription == "Grant type 'implicit' is not supported.", "Error description should be correct.")
            #expect(errorResponse.error == .invalidClientMetadata, "Error code should be equal 'invalid_client_metadata'.")
        }
        
        @Test("OAuth dynamic client should not be registered for response type not for authentication code")
        func oAuthDynamicClientShouldNotBeRegisteredForResponseTypeNotForAuthenticationCode() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.token])
                        
            // Act.
            let errorResponse = try await application.getResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientErrorDto.self
            )
            
            // Assert.
            #expect(errorResponse.errorDescription == "Response type 'code' is required for 'authorization_code'.", "Error description should be correct.")
            #expect(errorResponse.error == .invalidClientMetadata, "Error code should be equal 'invalid_client_metadata'.")
        }
        
        @Test("OAuth dynamic client should not be registered when response type 'token' has been specified")
        func oAuthDynamicClientShouldNotBeRegisteredWhenReponseTypeTokenHasBeenSpecified() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.authorizationCode],
                                                                              responseTypes: [OAuthResponseTypeDto.code, OAuthResponseTypeDto.token])
                        
            // Act.
            let errorResponse = try await application.getResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientErrorDto.self
            )
            
            // Assert.
            #expect(errorResponse.errorDescription == "Response type 'token' is not supported (implicit grant type is not supported).", "Error description should be correct.")
            #expect(errorResponse.error == .invalidClientMetadata, "Error code should be equal 'invalid_client_metadata'.")
        }
        
        @Test("OAuth dynamic client should not be registered for client credentials without token endpoint authentication")
        func oAuthDynamicClientShouldNotBeRegisteredForClientCredentialsWithoutTokenEndpointAuthentication() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.clientCredentials],
                                                                              responseTypes: [])
                        
            // Act.
            let errorResponse = try await application.getResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientErrorDto.self
            )
            
            // Assert.
            #expect(errorResponse.errorDescription == "For 'client_credentials' grant type, 'client_secret_basic' or 'client_secret_post' token endpoint authentication method is required.", "Error description should be correct.")
            #expect(errorResponse.error == .invalidClientMetadata, "Error code should be equal 'invalid_client_metadata'.")
        }
        
        @Test("OAuth dynamic client should not be registered for client credentials without user")
        func oAuthDynamicClientShouldNotBeRegisteredForClientCredentialsWithoutUser() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              tokenEndpointAuthMethod: .clientSecretPost,
                                                                              grantTypes: [OAuthGrantTypeDto.clientCredentials],
                                                                              responseTypes: [])
                        
            // Act.
            let errorResponse = try await application.getResponse(
                to: "/auth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientErrorDto.self
            )
            
            // Assert.
            #expect(errorResponse.errorDescription == "Client credentials grant type requires authentication (specify 'Authenticate: Bearer' header).", "Error description should be correct.")
            #expect(errorResponse.error == .invalidClientMetadata, "Error code should be equal 'invalid_client_metadata'.")
        }
    }
}
