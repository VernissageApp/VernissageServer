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

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        let level = try LoggingSystem.logLevel(from: &env)

        LoggingSystem.bootstrap { label -> LogHandler in
            MultiplexLogHandler([
                ConsoleLogger(label: label, console: Terminal(), level: level),
                FileLogger(label: label, path: "Logs/vernissage.log", level: level)
            ])
        }

        let app = Application(env)
        defer { app.shutdown() }

        try await app.configure()
        try app.run()
    }
}
