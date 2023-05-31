import Vapor

struct EmailAddressDto {
    var address: String
    var name: String?
}

extension EmailAddressDto: Content { }
