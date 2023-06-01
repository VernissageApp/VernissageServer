//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
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
                       svgIcon: String?) throws -> AuthClient {

        let authClient = AuthClient(type: type,
                                    name: name,
                                    uri: uri,
                                    tenantId: tenantId,
                                    clientId: clientId,
                                    clientSecret: clientSecret,
                                    callbackUrl: callbackUrl,
                                    svgIcon: svgIcon)

        try authClient.save(on: SharedApplication.application().db).wait()

        return authClient
    }

    static func get(uri: String) throws -> AuthClient {
        guard let authClient = try AuthClient.query(on: SharedApplication.application().db).filter(\.$uri == uri).first().wait() else {
            throw SharedApplicationError.unwrap
        }

        return authClient
    }
}
