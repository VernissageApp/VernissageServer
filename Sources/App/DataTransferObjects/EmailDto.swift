import Vapor

struct EmailDto {
    var to: EmailAddressDto
    var subject: String
    var body: String
    var from: EmailAddressDto?
    var replyTo: EmailAddressDto?
}

extension EmailDto: Content { }
