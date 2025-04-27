//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import PostgresKit

extension SQLPostgresConfiguration {
    public var string: String {
        let configuration = self.coreConfiguration

        let internalHost = configuration.host ?? "<unknown>"
        let internalPort = if let portInt = configuration.port { "\(portInt)" } else { "<default>" }
        let tlsModeString = configuration.tls.isAllowed ? (configuration.tls.isEnforced ? "enabled/required" : "enabled/not required") : "disabled"
        
        return "postgres://\(configuration.username):********@\(internalHost):\(internalPort) (tls: \(tlsModeString))"
    }
}
