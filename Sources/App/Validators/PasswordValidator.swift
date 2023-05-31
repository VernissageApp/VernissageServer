import Vapor

extension Validator where T == String {
    /// Validates whether a `String` is a valid email address.
    public static var password: Validator<T> {
        .init {
            guard
                let range = $0.range(of: "^(?:(?=.*[a-z])(?:(?=.*[A-Z])(?=.*[\\d\\W])|(?=.*\\W)(?=.*\\d))|(?=.*\\W)(?=.*[A-Z])(?=.*\\d)).{8,}$",
                                    options: [.regularExpression, .caseInsensitive]),
                range.lowerBound == $0.startIndex && range.upperBound == $0.endIndex
            else {
                return ValidatorResults.Password(isValidPassword: false)
            }

            return ValidatorResults.Password(isValidPassword: true)
        }
    }
}

extension ValidatorResults {
    /// `ValidatorResult` of a validator that validates whether a `String` is a valid email address.
    public struct Password {
        /// The input is a valid email address
        public let isValidPassword: Bool
    }
}

extension ValidatorResults.Password: ValidatorResult {
    public var isFailure: Bool {
        !self.isValidPassword
    }
    
    public var successDescription: String? {
        "is a valid password"
    }
    
    public var failureDescription: String? {
        "is not a valid password"
    }
}
