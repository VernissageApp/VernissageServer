import Vapor

struct OAuthRequest: Content {
    enum CodingKeys: String, CodingKey {
        case url, code
        case clientId = "client_id"
        case clientSecret = "client_secret"
        case redirectUri = "redirect_uri"
        case grantType = "grant_type"
    }
    
    var url: String
    var code: String
    var clientId: String
    var clientSecret: String
    var redirectUri: String
    var grantType: String
}
