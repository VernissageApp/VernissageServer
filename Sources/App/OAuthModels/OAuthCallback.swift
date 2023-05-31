import Vapor

struct OAuthCallback: Content {
    var code: String?
    var state: String?
    var scope: String?
    var authuser: String?
    var prompt: String?
}
