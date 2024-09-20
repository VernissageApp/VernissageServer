//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit
@preconcurrency import Frostflake

extension Application.Services {
    struct SnowflakeServiceKey: StorageKey {
        typealias Value = SnowflakeServiceType
    }

    var snowflakeService: SnowflakeServiceType {
        get {
            self.application.storage[SnowflakeServiceKey.self] ?? SnowflakeService()
        }
        nonmutating set {
            self.application.storage[SnowflakeServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol SnowflakeServiceType: Sendable {
    func generate() -> Int64
}

/// A service for generating snowflake style identifiers (used as primary key in database).
final class SnowflakeService: SnowflakeServiceType {
    let frostflake: Frostflake
    
    init() {
        frostflake = Frostflake(generatorIdentifier: 1)
    }
    
    func generate() -> Int64 {
        .init(bitPattern: frostflake.generate())
    }
}
