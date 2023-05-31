import Vapor

struct OAuthUser {
    let uniqueId: String
    let email: String
    let familyName: String?
    let givenName: String?
    let name: String?
}
