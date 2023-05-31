import Vapor

struct LoginRequestDto {
    var userNameOrEmail: String
    var password: String
}

extension LoginRequestDto: Content { }
