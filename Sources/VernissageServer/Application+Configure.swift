//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import QueuesRedisDriver
import ExtendedError
import ExtendedConfiguration
import JWT
import Smtp
import Frostflake
import SotoCore
import SotoSNS
import Leaf
import NIOCore

extension Application {

    /// Called before your application initializes.
    public func configure() async throws {
        // Snowflakes id's generator have to be set up at the start of the application.
        initSnowflakesGenerator()
        
        // Configure default JSON encoder/decoder used to build responses.
        configureJsonCoders()
        
        // Register routes to the router.
        try registerControllers()
        
        // Initialize configuration from file and system environment.
        try initConfiguration()
        
        // Configure database.
        try configureDatabase()
        
        // Migrate database.
        try await migrateDatabase()
        
        // Seed database common data.
        try await seedDictionaries()
        
        // Read configuration from database and set in cache.
        try await initCacheConfiguration()
        
        // Seed administrator into database.
        try await seedAdmin()
        
        // Register middleware.
        registerMiddlewares()
        
        // Register queues.
        try registerQueues()
        
        // Register schedulers.
        try registerSchedulers()
        
        // Set up email settings.
        try await initEmailSettings()
        
        // Configure S3 support.
        await configureS3()
                
        // Init Leaf for view rendering.
        self.views.use(.leaf)
    }

    private func initSnowflakesGenerator() {
        self.services.snowflakeService = SnowflakeService()
        self.logger.info("Snowflake id generator has been initialized with node id: '\(self.services.snowflakeService.getNodeId())'.")
    }
    
    private func registerMiddlewares() {
        // Read CORS origin from settings table.
        var corsOrigin = CORSMiddleware.AllowOriginSetting.originBased
        
        let applicationSettings = self.settings.cached
        if let corsOriginSettig = applicationSettings?.corsOrigin, corsOriginSettig != "" {
            corsOrigin = .custom(corsOriginSettig)
        }
                
        // Cors middleware.
        let corsConfiguration = CORSMiddleware.Configuration(
            allowedOrigin: corsOrigin,
            allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
            allowedHeaders: [.accept,
                             .authorization,
                             .contentType,
                             .origin,
                             .xRequestedWith,
                             .userAgent,
                             .accessControlAllowOrigin,
                             HTTPHeaders.Name(Constants.twoFactorTokenHeader),
                             HTTPHeaders.Name(Constants.xsrfTokenHeader)
            ],
            allowCredentials: true
        )
        let corsMiddleware = CORSMiddleware(configuration: corsConfiguration)
        self.middleware.use(corsMiddleware, at: .beginning)
        
        // Custom response header middleware.
        let errorMiddleware = CustomErrorMiddleware()
        self.middleware.use(errorMiddleware)
        
        // Atatch security headers to HTTP response.
        let securityHeadersMiddleware = SecurityHeadersMiddleware()
        self.middleware.use(securityHeadersMiddleware)
        
        // Configure public files middleware.
        let publicFolderPath = self.directory.publicDirectory
        let fileMiddleware = FileMiddleware(
            publicDirectory: publicFolderPath
        )

        self.logger.info("Local files will be saved into directory '\(publicFolderPath)'.")
        self.middleware.use(fileMiddleware)
    }
    
    private func initConfiguration() throws {        
        self.logger.info("Init configuration for environment: '\(self.environment.name)'.")
        let workingDirectory = self.directory.workingDirectory
        
        try self.settings.load([
            .jsonFile("\(workingDirectory)appsettings.json", optional: false),
            .jsonFile("\(workingDirectory)appsettings.\(self.environment.name).json", optional: true),
            .jsonFile("\(workingDirectory)appsettings.local.json", optional: true),
            .environmentVariables(.withPrefix("vernissage."))
        ])
                
        self.settings.configuration.all().forEach { (key: String, value: Any) in
            self.logger.info("Configuration: '\(key)', value: '\(value)'.")
        }
    }

    private func configureDatabase(clearDatabase: Bool = false) throws {
        let processorCount = ProcessInfo.processInfo.processorCount
        let activeProcessorCount = ProcessInfo.processInfo.activeProcessorCount
        let systemCoreCount = System.coreCount
        let eventLoopCount = self.eventLoopGroup.makeIterator().reduce(0) { count, _ in count + 1 }
        
        self.logger.notice(
            "Runtime summary: processorCount=\(processorCount), activeProcessorCount=\(activeProcessorCount), System.coreCount=\(systemCoreCount), eventLoopCount=\(eventLoopCount)."
        )
        
        // In testing environmebt we are using in memory database.
        if self.environment == .testing {
            self.logger.notice("In memory SQLite is used during testing (testing environment is set).")
            self.databases.use(.sqlite(.memory), as: .sqlite)
            return
        }
        
        // Retrieve connection string from configuration settings.
        guard let connectionString = self.settings.getString(for: "vernissage.connectionString") else {
            self.logger.notice("In memory SQLite has been used (connection string is not set).")
            self.databases.use(.sqlite(.memory), as: .sqlite)
            return
        }
        
        // When environment variable is not configured we are using in memory database.
        guard let connectionUrl = URL(string: connectionString) else {
            self.logger.notice("In memory SQLite has been used (incorrect URL is set: \(connectionString)).")
            self.databases.use(.sqlite(.memory), as: .sqlite)
            return
        }
        
        // Configuration for Postgres.
        if connectionUrl.scheme?.hasPrefix("postgres") == true {
            self.logger.notice("Postgres database is configured in connection string.")
            
            let dbMaxConnectionsPerEventLoop = self.settings.getPositiveInt(for: "vernissage.dbMaxConnectionsPerEventLoop", withDefault: 1)
            let dbConnectionPoolTimeoutSeconds = self.settings.getPositiveInt(for: "vernissage.dbConnectionPoolTimeoutSeconds", withDefault: 10)
            let dbConnectTimeoutSeconds = self.settings.getPositiveInt(for: "vernissage.dbConnectTimeoutSeconds", withDefault: 10)
            let maxDatabaseConnections = dbMaxConnectionsPerEventLoop * eventLoopCount
            
            var configuration = try SQLPostgresConfiguration(url: connectionUrl)
            configuration.coreConfiguration.options.connectTimeout = .seconds(Int64(dbConnectTimeoutSeconds))
            
            self.logger.info("Connecting to database: '\(configuration.string)'.")
            let postgresPoolConfiguration = "Postgres pool configuration: "
                + "maxConnectionsPerEventLoop=\(dbMaxConnectionsPerEventLoop), "
                + "connectionPoolTimeoutSeconds=\(dbConnectionPoolTimeoutSeconds), "
                + "connectTimeoutSeconds=\(dbConnectTimeoutSeconds)."
            self.logger.notice("\(postgresPoolConfiguration)")
            self.logger.notice("Postgres capacity summary: maxDatabaseConnections=\(maxDatabaseConnections) (eventLoopCount=\(eventLoopCount) * maxConnectionsPerEventLoop=\(dbMaxConnectionsPerEventLoop)).")

            self.databases.use(.postgres(configuration: configuration,
                                         maxConnectionsPerEventLoop: dbMaxConnectionsPerEventLoop,
                                         connectionPoolTimeout: .seconds(Int64(dbConnectionPoolTimeoutSeconds))), as: .psql)
            return
        }
        
        // When we have environment variable but it's not Postgres we are trying to run SQLite in file.
        self.logger.notice("SQLite file database is configured in environment variable (file: \(connectionUrl.path)).")
        self.databases.use(.sqlite(.file(connectionUrl.path)), as: .sqlite)
    }
    
    private func migrateDatabase() async throws {
        registerMigrations()
        try await self.autoMigrate()
    }

    public func initCacheConfiguration() async throws {
        let settingsFromDb = try await self.services.settingsService.get(on: self.db)
        let applicationSettings = try await self.services.settingsService.getApplicationSettings(basedOn: settingsFromDb, application: self)
        
        self.settings.set(applicationSettings, for: ApplicationSettings.self)
    }
    
    private func initEmailSettings() async throws {
        let hostName = try await self.services.settingsService.get(.emailHostname, on: self.db)
        let port = try await self.services.settingsService.get(.emailPort, on: self.db)
        let userName = try await self.services.settingsService.get(.emailUserName, on: self.db)
        let password = try await self.services.settingsService.get(.emailPassword, on: self.db)
        let secureMethod = try await self.services.settingsService.get(.emailSecureMethod, on: self.db)
        
        self.services.emailsService.setServerSettings(hostName: hostName,
                                                      port: port,
                                                      userName: userName,
                                                      password: password,
                                                      secureMethod: secureMethod,
                                                      on: self)
    }
    
    private func configureS3() async {
        // In testing environment queues are disabled.
        if self.environment == .testing {
            self.logger.notice("S3 object storage is disabled during testing (testing environment is set).")
            return
        }
        
        let applicationSettings = self.settings.cached

        guard let s3Address = applicationSettings?.s3Address else {
            self.logger.notice("S3 object storage address is not set (local folder will be used).")
            return
        }
        
        guard let s3AccessKeyId = applicationSettings?.s3AccessKeyId else {
            self.logger.notice("S3 object storage access key is not set (local folder will be used).")
            return
        }
        
        guard let s3SecretAccessKey = applicationSettings?.s3SecretAccessKey else {
            self.logger.notice("S3 object storage secret access key is not set (local folder will be used).")
            return
        }
        
        guard let s3Bucket = applicationSettings?.s3Bucket else {
            self.logger.notice("S3 object storage bucket name is not set (local folder will be used).")
            return
        }

        let awsClient = self.configureAwsClient(s3AccessKeyId: s3AccessKeyId, s3SecretAccessKey: s3SecretAccessKey)
        self.objectStorage.client = awsClient
        
        if let s3Region = applicationSettings?.s3Region, s3Region.count > 0 {
            self.logger.info("Attachment media files will saved into Amazon S3 object storage: '\(s3Address)', bucket: '\(s3Bucket)', region: '\(s3Region)'.")
            await self.objectStorage.setS3(S3(client: awsClient, region: .init(rawValue: s3Region)))
        } else {
            self.logger.info("Attachment media files will saved into custom S3 object storage: '\(s3Address)', bucket: '\(s3Bucket)'.")
            await self.objectStorage.setS3(S3(client: awsClient, endpoint: s3Address))
        }
    }
    
    private func configureAwsClient(s3AccessKeyId: String, s3SecretAccessKey: String) -> AWSClient {
        let s3Http1OnlyMode = self.settings.getString(for: "vernissage.s3Http1OnlyMode")
        if s3Http1OnlyMode == nil || s3Http1OnlyMode == "false" {
            self.logger.info("S3 object storage bucket will be configured with automatic HTTP version mode.")

            let awsClient = AWSClient(
                credentialProvider: .static(accessKeyId: s3AccessKeyId, secretAccessKey: s3SecretAccessKey),
                logger: self.logger
            )
            
            return awsClient
        } else {
            self.logger.info("S3 object storage bucket will be configured with HTTP 1.0 version mode.")

            // To change http version we have to create own client (based on: `AsyncHTTPClient.Configuration+BrowserLike.swift` same as HTTPClient.shared).
            var httpConfiguration = HTTPClient.Configuration(
                certificateVerification: .fullVerification,
                redirectConfiguration: .follow(max: 20, allowCycles: false),
                timeout: .init(connect: .seconds(90), read: .seconds(90)),
                connectionPool: .seconds(600),
                proxy: nil,
                ignoreUncleanSSLShutdown: false,
                decompression: .enabled(limit: .ratio(25)),
                backgroundActivityLogger: nil
            )
            
            // Change client configuration for using .http1Only (https://github.com/soto-project/soto/issues/608).
            httpConfiguration.httpVersion = .http1Only
            
            // Configure AWS client.
            let awsClient = AWSClient(
                credentialProvider: .static(accessKeyId: s3AccessKeyId, secretAccessKey: s3SecretAccessKey),
                httpClient: HTTPClient(
                    eventLoopGroupProvider: .singleton,
                    configuration: httpConfiguration
                ),
                logger: self.logger
            )
            
            return awsClient
        }
    }
    
    private func configureJsonCoders() {
        // Create a new JSON encoder/decoder that uses unix-timestamp dates
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .customISO8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601
        
        // Override the global encoder used for the `.json` media type
        ContentConfiguration.global.use(encoder: encoder, for: .json)
        ContentConfiguration.global.use(decoder: decoder, for: .json)
    }
}
