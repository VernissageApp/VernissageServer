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
    
    @Suite("AuthenticationDynamicClients (POST /oauth-dynamic-clients)", .serialized, .tags(.authDynamicClients))
    struct AuthenticationDynamicClientsRegisterActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Auth dynamic client should be registered with minimum required metadata")
        func authDynamicClientShouldBeRegisteredWithMinimumRequiredMetadata() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://localhost.com/callback"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code])
            
            // Act.
            let createdAuthDtoDto = try await application.getResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientResponseDto.self
            )
            
            // Assert.
            #expect(createdAuthDtoDto.clientId.count > 0, "Auth client id wasn't created.")
        }
        
        @Test("Auth dynamic client should be registered with all metadata")
        func authDynamicClientShouldBeRegisteredWithAllMetadata() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://localhost.com/callback"],
                                                                              tokenEndpointAuthMethod: OAuthTokenEndpointAuthMethodDto.none,
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
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
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientResponseDto.self
            )
            
            // Assert.
            #expect(createdAuthDtoDto.clientId.count > 0, "Auth client id wasn't created.")
            #expect(createdAuthDtoDto.redirectUris.contains(where: { $0 ==  "https://localhost.com/callback" }), "Redirect Uris should be saved correctly.")
            #expect(createdAuthDtoDto.tokenEndpointAuthMethod == OAuthTokenEndpointAuthMethodDto.none, "Token endpoint auth method should be saved correctly.")
            #expect(createdAuthDtoDto.grantTypes.contains(where: { $0 == OAuthGrantTypeDto.implicit }), "Grant types should be saved correctly.")
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
        
        @Test("Auth dynamic client should not be registered without redirect url")
        func authDynamicClientShouldNotBeRegisteredWithoutRedirectUrl() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: [],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code])
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
        }
        
        @Test("Auth dynamic client should be registered with default grant types")
        func authDynamicClientShouldBeRegisteredWithDefaultGrantTypes() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://localhost.com/callback"],
                                                                              grantTypes: [],
                                                                              responseTypes: [OAuthResponseTypeDto.code])
            
            // Act.
            let createdAuthDtoDto = try await application.getResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientResponseDto.self
            )
            
            // Assert.
            #expect(createdAuthDtoDto.grantTypes.contains(where: { $0 == OAuthGrantTypeDto.authorizationCode }), "Auth client not created.")
        }
        
        @Test("Auth dynamic client should be registered with default response types")
        func authDynamicClientShouldBeRegisteredWithDefaultResponseTypes() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://localhost.com/callback"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [])
            
            // Act.
            let createdAuthDtoDto = try await application.getResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto,
                decodeTo: RegisterOAuthClientResponseDto.self
            )
            
            // Assert.
            #expect(createdAuthDtoDto.responseTypes.contains(where: { $0 == OAuthResponseTypeDto.code }), "Auth client not created.")
        }
        
        @Test("Auth dynamic client should not be registered with too long client_name")
        func authDynamicClientShouldNotBeRegisteredWithTooLongClientName() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              clientName: String.createRandomString(length: 201))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("client_name") == "is not null and is greater than maximum of 200 character(s)")
        }
        
        @Test("Auth dynamic client should not be registered with too long scope")
        func authDynamicClientShouldNotBeRegisteredWithTooLongScope() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              scope: String.createRandomString(length: 101))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("scope") == "is not null and is greater than maximum of 100 character(s)")
        }
        
        @Test("Auth dynamic client should not be registered with too long software_id")
        func authDynamicClientShouldNotBeRegisteredWithTooLongSoftwareId() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              softwareId: String.createRandomString(length: 101))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("software_id") == "is not null and is greater than maximum of 100 character(s)")
        }
        
        @Test("Auth dynamic client should not be registered with too long software_version")
        func authDynamicClientShouldNotBeRegisteredWithTooLongSoftwareVersion() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              softwareVersion: String.createRandomString(length: 101))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("software_version") == "is not null and is greater than maximum of 100 character(s)")
        }
        
        @Test("Auth dynamic client should not be registered with too long client_uri")
        func authDynamicClientShouldNotBeRegisteredWithTooLongClientUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              clientUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("client_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("Auth dynamic client should not be registered with incorrect client_uri")
        func authDynamicClientShouldNotBeRegisteredWithIncorrectClientUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              clientUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("client_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("Auth dynamic client should not be registered with too long logo_uri")
        func authDynamicClientShouldNotBeRegisteredWithTooLongLogoUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              logoUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("logo_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("Auth dynamic client should not be registered with incorrect logo_uri")
        func authDynamicClientShouldNotBeRegisteredWithIncorrectLogoUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              logoUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("logo_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("Auth dynamic client should not be registered with too long tos_uri")
        func authDynamicClientShouldNotBeRegisteredWithTooLongTosUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              tosUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("tos_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("Auth dynamic client should not be registered with incorrect tos_uri")
        func authDynamicClientShouldNotBeRegisteredWithIncorrectTosUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              tosUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("tos_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("Auth dynamic client should not be registered with too long policy_uri")
        func authDynamicClientShouldNotBeRegisteredWithTooLongPolicyUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              policyUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("policy_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("Auth dynamic client should not be registered with incorrect policy_uri")
        func authDynamicClientShouldNotBeRegisteredWithIncorrectPolicyUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              policyUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("policy_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("Auth dynamic client should not be registered with too long jwks_uri")
        func authDynamicClientShouldNotBeRegisteredWithTooLongJwksUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https://redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              jwksUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("jwks_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
        
        @Test("Auth dynamic client should not be registered with incorrect jwks_uri")
        func authDynamicClientShouldNotBeRegisteredWithIncorrectJwksUri() async throws {
            
            // Arrange.
            let registerOAuthClientRequestDto = RegisterOAuthClientRequestDto(redirectUris: ["https:redirect.url"],
                                                                              grantTypes: [OAuthGrantTypeDto.implicit],
                                                                              responseTypes: [OAuthResponseTypeDto.code],
                                                                              jwksUri: String.createRandomString(length: 501))
                        
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/oauth-dynamic-clients",
                method: .POST,
                data: registerOAuthClientRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("jwks_uri") == "is not null and is greater than maximum of 500 character(s) and is an invalid URL")
        }
    }
}
