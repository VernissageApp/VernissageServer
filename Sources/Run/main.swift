import App
import Vapor
import ExtendedLogging

var env = try Environment.detect()
let level = try LoggingSystem.logLevel(from: &env)

LoggingSystem.bootstrap { label -> LogHandler in
    MultiplexLogHandler([
        ConsoleLogger(label: label, console: Terminal(), level: level),
        FileLogger(label: label, path: "Logs/users.log", level: level)
    ])
}

let app = Application(env)
defer { app.shutdown() }

try app.configure()
try app.run()
