//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Logging
import NIOCore
import NIOPosix
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

        // Bootstrap the logging system (console/file/sentry).
        LoggingSystem.bootstrap { label -> LogHandler in
            
            var loggers: [LogHandler] = []
            
            // Console logger is always available.
            loggers.append(ConsoleLogger(label: label, console: Terminal(), level: level))
            
            // Log file is available when environment is set.
            if let logFilePath = Environment.get("VERNISSAGE_LOG_PATH") {
                loggers.append(FileLogger(label: label, path: logFilePath, level: level))
            }
            
            // Sentry log is available when environment is set.
            if let sentryDsn = Environment.get("SENTRY_DSN") {
                loggers.append(SentryLogger(label: label,
                                            dsn: sentryDsn,
                                            application: Constants.name,
                                            version: Constants.version,
                                            level: Logger.Level.warning))
            }
            
            return MultiplexLogHandler(loggers)
        }

        // Creating new application.
        let app = try await Application.make(env)
                
        // Configure all providers/services.
        do {
            try await app.configure()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }

        // Run application.
        try await app.execute()
        
        // Graceful shutdown application.
        try await app.asyncShutdown()
    }
}
