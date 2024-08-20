//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
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
    /// Database is storing Int64 values, but id are in UInt64: https://github.com/vapor/postgres-nio/pull/120.
    func toId() -> Int64? {
        guard let unsignedInt = UInt64(self) else {
            return nil
        }

        return .init(bitPattern: unsignedInt)
    }
}
