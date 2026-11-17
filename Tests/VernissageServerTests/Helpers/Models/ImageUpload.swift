//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Foundation
import VaporTesting

struct ImageUpload {
    let application: Application
    let user: User
    let data: Data
    let form: MultipartFormData

    func send() async throws -> TestingHTTPResponse {
        try await application.sendRequest(
            as: .user(userName: user.userName, password: "p@ssword"),
            to: "/attachments", method: .POST,
            headers: .init([("content-type", "multipart/form-data; boundary=\(form.boundary)")]),
            body: form.build())
    }
}
