//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public extension JSONDecoder.DateDecodingStrategy {
    static let customISO8601 = custom {
        let container = try $0.singleValueContainer()

        let string = try container.decode(String.self)
        let customFormatter = CustomFormatter()
        
        if let date = customFormatter.iso8601withFractionalSeconds().date(from: string) ?? customFormatter.iso8601().date(from: string) {
            return date
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
    }
}
