import Vapor

struct ErrorBody: Content {
    var error: Bool;
    var code: String;
    var reason: String;
    var failures: [ValidationFailure]?
}
