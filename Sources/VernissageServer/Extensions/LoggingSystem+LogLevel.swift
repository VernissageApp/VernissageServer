//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Logging
import Vapor

extension LoggingSystem {
    public static func logLevel(from environment: inout Environment) throws -> Logger.Level {
        struct LogSignature: CommandSignature {
            @Option(name: "log", help: "Change log level")
            var level: Logger.Level?
            init() { }
        }

        // Determine log level from environment.
        let level = try LogSignature(from: &environment.commandInput).level
            ?? Environment.process.LOG_LEVEL
            ?? (environment == .production ? .notice: .info)

        return level
    }
}
