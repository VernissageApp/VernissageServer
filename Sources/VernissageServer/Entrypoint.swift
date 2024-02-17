//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Dispatch
import Logging
import ExtendedLogging

/// This extension is temporary and can be removed once Vapor gets this support.
private extension Vapor.Application {
    static let baseExecutionQueue = DispatchQueue(label: "vapor.codes.entrypoint")
    
    func runFromAsyncMainEntrypoint() async throws {
        try await withCheckedThrowingContinuation { continuation in
            Vapor.Application.baseExecutionQueue.async { [self] in
                do {
                    try self.run()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

/// The main entry point to the application.
@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        let level = try LoggingSystem.logLevel(from: &env)
                
        LoggingSystem.bootstrap { label -> LogHandler in
            MultiplexLogHandler([
                ConsoleLogger(label: label, console: Terminal(), level: level),
                FileLogger(label: label, path: "Logs/vernissage.log", level: level),
                SentryLogger(label: label,
                             dsn: Environment.get("SENTRY_DSN"),
                             application: Constants.name,
                             version: Constants.version,
                             level: Logger.Level.warning)
            ])
        }

        let app = Application(env)
        defer { app.shutdown() }

        try await app.configure()
        try await app.execute()
    }
}
