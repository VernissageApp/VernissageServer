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

protocol CaptchaServiceType {
    func validate(on request: Request, captchaFormResponse: String) async throws -> Bool
}

final class CaptchaService: CaptchaServiceType {

    public func validate(on request: Request, captchaFormResponse: String) async throws -> Bool {
        let result = try await request.validate(captchaFormResponse: captchaFormResponse)
        return result
    }
}
