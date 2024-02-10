//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Recaptcha

extension Application.Services {
    struct CaptchaServiceKey: StorageKey {
        typealias Value = CaptchaServiceType
    }

    var captchaService: CaptchaServiceType {
        get {
            self.application.storage[CaptchaServiceKey.self] ?? CaptchaService()
        }
        nonmutating set {
            self.application.storage[CaptchaServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol CaptchaServiceType {
    func validate(on request: Request, captchaFormResponse: String) async throws -> Bool
}

final class CaptchaService: CaptchaServiceType {

    public func validate(on request: Request, captchaFormResponse: String) async throws -> Bool {
        let result = try await request.validate(captchaFormResponse: captchaFormResponse)
        return result
    }
}
