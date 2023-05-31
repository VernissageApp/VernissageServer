import Vapor

struct BooleanResponseDto {
    var result: Bool
}

extension BooleanResponseDto: Content { }
