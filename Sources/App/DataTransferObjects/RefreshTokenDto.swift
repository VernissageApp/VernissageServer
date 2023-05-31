import Vapor

struct RefreshTokenDto {
    var refreshToken: String
}

extension RefreshTokenDto: Content { }
