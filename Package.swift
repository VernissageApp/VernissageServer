// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "VernissageServer",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),

        // 🖋 Non-blocking, event-driven Swift client for PostgreSQL.
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),

        // 🐘 Swift ORM (queries, models, relations, etc) built on PostgreSQL.
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.1.0"),
        
        // 🗄 Fluent driver for SQLite.
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),

        // 🔏 JSON Web Token signing and verification (HMAC, RSA).
        .package(url: "https://github.com/vapor/jwt.git", from: "4.0.0"),

        // 🔑 Google Recaptcha for securing anonymous endpoints.
        .package(url: "https://github.com/Mikroservices/Recaptcha.git", from: "2.0.0"),

        // 📘 Custom logger handlers.
        .package(url: "https://github.com/Mikroservices/ExtendedLogging.git", from: "1.0.0"),
        
        // 📒 Library provides mechanism for reading configuration files.
        .package(url: "https://github.com/Mikroservices/ExtendedConfiguration.git", from: "1.0.0"),
        
        // 🐞 Custom error middleware for Vapor.
        .package(url: "https://github.com/Mikroservices/ExtendedError.git", from: "2.0.0"),
        
        // 📖 Apple logger hander.
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        
        // 🔐 Swift Crypto is an open-source implementation of a substantial portion of the API of Apple CryptoKit suitable for use on Linux platforms.
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.5.0"),
        
        // ⏱️ Vapor Queues driver for Redis database.
        .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.1.0"),
        
        // 📧 SMTP protocol support for the Vapor web framework.
        .package(url: "https://github.com/Mikroservices/Smtp.git", from: "3.0.3"),
        
        // 🆔 High performance unique ID generator for Swift inspired by Snowflake.
        .package(url: "https://github.com/ordo-one/package-frostflake", from: "3.0.1"),
        
        // 🔁 ActivityPub client.
        .package(url: "https://github.com/VernissageApp/ActivityPubKit.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ExtendedLogging", package: "ExtendedLogging"),
                .product(name: "ExtendedError", package: "ExtendedError"),
                .product(name: "ExtendedConfiguration", package: "ExtendedConfiguration"),
                .product(name: "Recaptcha", package: "Recaptcha"),
                .product(name: "QueuesRedisDriver", package: "queues-redis-driver"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "ActivityPubKit", package: "ActivityPubKit"),
                .product(name: "Smtp", package: "Smtp"),
                .product(name: "Frostflake", package: "package-frostflake")
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor")
        ])
    ]
)
