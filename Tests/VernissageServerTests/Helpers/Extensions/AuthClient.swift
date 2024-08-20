//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension AuthClient {

    static func create(type: AuthClientType,
                       name: String,
                       uri: String,
                       tenantId: String?,
                       clientId: String,
                       clientSecret: String,
                       callbackUrl: String,
                       svgIcon: String?) async throws -> AuthClient {

        let authClient = AuthClient(type: type,
                                    name: name,
                                    uri: uri,
                                    tenantId: tenantId,
                                    clientId: clientId,
                                    clientSecret: clientSecret,
                                    callbackUrl: callbackUrl,
                                    svgIcon: svgIcon)

        try await authClient.save(on: SharedApplication.application().db)

        return authClient
    }

    static func get(uri: String) async throws -> AuthClient {
        guard let authClient = try await AuthClient.query(on: SharedApplication.application().db).filter(\.$uri == uri).first() else {
            throw SharedApplicationError.unwrap
        }

        return authClient
    }
}
