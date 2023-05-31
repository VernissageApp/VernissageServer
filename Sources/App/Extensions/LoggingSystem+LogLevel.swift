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

        // Disable stack traces if log level > debug.
        if level > .debug {
            StackTrace.isCaptureEnabled = false
        }

        return level
    }
}
