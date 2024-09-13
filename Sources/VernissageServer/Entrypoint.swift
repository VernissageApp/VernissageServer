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

/// The main entry point to the application.
@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let level = try LoggingSystem.logLevel(from: &env)
        
        // Commented to check if this code is responsible for application crashes.
        /*
        let logFilePath = Environment.get("VERNISSAGE_LOG_PATH")
        let sentryDsn = Environment.get("SENTRY_DSN")

        // Bootstrap the logging system (console/file/sentry).
        LoggingSystem.bootstrap { label -> LogHandler in
            
            var loggers: [LogHandler] = []
            
            // Console logger is always available.
            loggers.append(ConsoleLogger(label: label, console: Terminal(), level: level))
            
            // Log file is available when environment is set.
            if let logFilePath {
                loggers.append(FileLogger(label: label, path: logFilePath, level: level))
            }
            
            // Sentry log is available when environment is set.
            if let sentryDsn {
                loggers.append(SentryLogger(label: label,
                                            dsn: sentryDsn,
                                            application: Constants.name,
                                            version: Constants.version,
                                            level: Logger.Level.warning))
            }
            
            return MultiplexLogHandler(loggers)
        }
        */

        // Creating new application.
        let app = try await Application.make(env)
        
        // This attempts to install NIO as the Swift Concurrency global executor.
        // You can enable it if you'd like to reduce the amount of context switching between NIO and Swift Concurrency.
        // Note: this has caused issues with some libraries that use `.wait()` and cleanly shutting down.
        // If enabled, you should be careful about calling async functions before this point as it can cause assertion failures.
        // let executorTakeoverSuccess = NIOSingletons.unsafeTryInstallSingletonPosixEventLoopGroupAsConcurrencyGlobalExecutor()
        // app.logger.debug("Tried to install SwiftNIO's EventLoopGroup as Swift's global concurrency executor", metadata: ["success": .stringConvertible(executorTakeoverSuccess)])
                
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
