import Vapor

struct AccessTokenDto {
    var accessToken: String
    var refreshToken: String
}

extension AccessTokenDto: Content { }
