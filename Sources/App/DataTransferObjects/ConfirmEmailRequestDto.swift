import Vapor

struct ConfirmEmailRequestDto {
    var id: UUID
    var confirmationGuid: String
}

extension ConfirmEmailRequestDto: Content { }
