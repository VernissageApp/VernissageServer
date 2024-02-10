//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension DatabaseSchema.DataType {
    public static func varchar(_ size: Int) -> DatabaseSchema.DataType {
        return .custom("VARCHAR(\(size))")
    }
}
