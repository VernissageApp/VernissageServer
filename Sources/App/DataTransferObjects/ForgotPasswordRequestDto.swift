import Vapor

struct ForgotPasswordRequestDto {
    var email: String
    var redirectBaseUrl: String
}

extension ForgotPasswordRequestDto: Content { }
