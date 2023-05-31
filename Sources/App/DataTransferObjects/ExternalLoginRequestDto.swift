import Vapor

struct ExternalLoginRequestDto {
    var authenticateToken: String
}

extension ExternalLoginRequestDto: Content { }
