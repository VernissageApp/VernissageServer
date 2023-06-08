//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Foundation

extension Model {
    func stringId() -> String? {
        if let idValue = self.id {
            return "\(idValue)"
        }
        
        return nil
    }
}

extension String {
    func toId() -> UInt64? {
        return UInt64(self)
    }
}
