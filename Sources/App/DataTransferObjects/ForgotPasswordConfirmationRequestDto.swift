import Vapor

struct ForgotPasswordConfirmationRequestDto {
    var forgotPasswordGuid: String
    var password: String
}

extension ForgotPasswordConfirmationRequestDto: Content { }

extension ForgotPasswordConfirmationRequestDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("password", as: String.self, is: .count(8...32) && .password)
    }
}
