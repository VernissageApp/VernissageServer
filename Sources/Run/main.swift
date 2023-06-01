//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import App
import Vapor
import ExtendedLogging

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

try app.configure()
try app.run()
