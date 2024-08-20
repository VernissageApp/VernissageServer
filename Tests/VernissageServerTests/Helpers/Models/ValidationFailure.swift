//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ValidationFailure: Content {
    var field: String
    var failure: String?
}

extension Array where Element == ValidationFailure {
    func getFailure(_ field: String) -> String? {
        for item in self {
            if item.field == field {
                return item.failure
            }
        }
        
        return nil
    }
}
