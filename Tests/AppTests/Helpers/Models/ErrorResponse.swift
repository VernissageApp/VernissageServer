import Vapor

struct ErrorResponse {
    var error: ErrorBody;
    var status: HTTPResponseStatus;
}
