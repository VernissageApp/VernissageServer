//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Date {
    public static var yesterday: Date {
        return Date.now.addingTimeInterval(-86400)
    }
}
