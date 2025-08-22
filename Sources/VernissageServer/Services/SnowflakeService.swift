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
    /// Generates a new unique snowflake identifier.
    ///
    /// - Returns: A new unique 64-bit integer identifier.
    func generate() -> Int64

    /// Returns the unique node identifier for this snowflake generator instance.
    ///
    /// - Returns: The 16-bit node identifier used for ID generation.
    func getNodeId() -> UInt16
}

/// A service for generating snowflake style identifiers (used as primary key in database).
final class SnowflakeService: SnowflakeServiceType {
    let frostflake: Frostflake
    let nodeId: UInt16
    
    init() {
        // Node id is randomly generated for each API instance (that should reduce collisions).
        nodeId = UInt16.random(in: 1..<1000)
        
        // We have to force time regeneration during each id generation to be sure that id's have proper order between instances.
        frostflake = Frostflake(generatorIdentifier: nodeId, forcedTimeRegenerationInterval: 1)
    }
    
    func getNodeId() -> UInt16 {
        self.nodeId
    }
    
    func generate() -> Int64 {
        .init(bitPattern: frostflake.generate().rawValue)
    }
}
