//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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

extension Application {

    /// Called before your application initializes.
    public func configure() async throws {
        // Snowflakes id's generator have to be set up at the start of the application.
        initSnowflakesGenerator()
        
        // Register routes to the router.
        try routes()
        
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
        
        // Set up email settings.
        try await initEmailSettings()
    }

    private func initSnowflakesGenerator() {
        Frostflake.setup(sharedGenerator: Frostflake(generatorIdentifier: 1))
    }
    
    /// Register your application's routes here.
    private func routes() throws {
        // Basic response.
        self.get { _ in
            return "Service is up and running!"
        }

        // Configuring wellknown controller.
        try self.register(collection: WellKnownController())
        
        // Configuring ActivityPub controllers.
        try self.register(collection: ActivityPubController())
        try self.register(collection: ActivityPubSharedController())

        // Configure NodeInfo controller.
        try self.register(collection: NodeInfoController())
        
        // Configure API controllers.
        try self.register(collection: UsersController())
        try self.register(collection: AccountController())
        try self.register(collection: RegisterController())
        try self.register(collection: RolesController())
        try self.register(collection: UserRolesController())
        try self.register(collection: IdentityController())
        try self.register(collection: SettingsController())
        try self.register(collection: AuthenticationClientsController())
        try self.register(collection: SearchController())
    }
    
    private func registerMiddlewares() {
        // Read CORS origin from settings table.
        var corsOrigin = CORSMiddleware.AllowOriginSetting.all
        
        let appplicationSettings = self.settings.cached
        if let corsOriginSettig = appplicationSettings?.corsOrigin, corsOriginSettig != "" {
            corsOrigin = .custom(corsOriginSettig)
        }
        
        // Cors middleware.
        let corsConfiguration = CORSMiddleware.Configuration(
            allowedOrigin: corsOrigin,
            allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
            allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
        )
        let corsMiddleware = CORSMiddleware(configuration: corsConfiguration)
        self.middleware.use(corsMiddleware)

        // Catches errors and converts to HTTP response.
        let errorMiddleware = CustomErrorMiddleware()
        self.middleware.use(errorMiddleware)
        
        // Configure public files middleware.        
        guard let publicFolderPath = appplicationSettings?.publicFolderPath else {
            self.logger.warning("Local files path has not been set. Files will be not saved.")
            return
        }

        let fileMiddleware = FileMiddleware(
            publicDirectory: publicFolderPath
        )

        self.logger.info("Local files will be saved into directory '\(publicFolderPath)'.")
        self.middleware.use(fileMiddleware)
    }
    
    private func initConfiguration() throws {
        self.logger.info("Init configuration for environment: '\(self.environment.name)'.")
        
        try self.settings.load([
            .jsonFile("appsettings.json", optional: false),
            .jsonFile("appsettings.\(self.environment.name).json", optional: true),
            .jsonFile("appsettings.local.json", optional: true),
            .environmentVariables(.withPrefix("vernissage."))
        ])
                
        self.settings.configuration.all().forEach { (key: String, value: Any) in
            self.logger.info("Configuration: '\(key)', value: '\(value)'.")
        }
    }

    private func configureDatabase(clearDatabase: Bool = false) throws {
        // In testing environmebt we are using in memory database.
        if self.environment == .testing {
            self.logger.warning("In memory SQLite is used during testing (testing environment is set).")
            self.databases.use(.sqlite(.memory), as: .sqlite)
            return
        }
        
        // Retrieve connection string from configuration settings.
        guard let connectionString = self.settings.getString(for: "vernissage.connectionString") else {
            self.logger.warning("In memory SQLite has been used (connection string is not set).")
            self.databases.use(.sqlite(.memory), as: .sqlite)
            return
        }
        
        // When environment variable is not configured we are using in memory database.
        guard let connectionUrl = URLComponents(string: connectionString) else {
            self.logger.warning("In memory SQLite has been used (incorrect URL is set: \(connectionString)).")
            self.databases.use(.sqlite(.memory), as: .sqlite)
            return
        }
        
        // Configuration for Postgres.
        if connectionUrl.scheme?.hasPrefix("postgres") == true {
            self.logger.info("Postgres database is configured in connection string.")
            try self.configurePostgres(connectionUrl: connectionUrl)
            return
        }
        
        // When we have environment variable but it's not Postgres we are trying to run SQLite in file.
        self.logger.warning("SQLite file database is configured in environment variable (file: \(connectionUrl.path)).")
        self.databases.use(.sqlite(.file(connectionUrl.path)), as: .sqlite)
    }
    
    private func migrateDatabase() async throws {
        // Configure migrations
        self.migrations.add(CreateUsers())
        self.migrations.add(CreateRefreshTokens())
        self.migrations.add(CreateSettings())
        self.migrations.add(CreateRoles())
        self.migrations.add(CreateUserRoles())
        self.migrations.add(CreateEvents())
        self.migrations.add(CreateAuthClients())
        self.migrations.add(CreateExternalUsers())
        self.migrations.add(CreateFollows())
        self.migrations.add(CreateInstanceBlockedDomains())
        self.migrations.add(CreateUserBlockedDomains())
        self.migrations.add(CreateLocalizables())
        self.migrations.add(CreateInvitations())
        
        self.migrations.add(UsersHeaderField())
        
        try await self.autoMigrate()
    }

    public func initCacheConfiguration() async throws {
        let settingsFromDb = try await self.services.settingsService.get(on: self)
        let applicationSettings = try self.services.settingsService.getApplicationSettings(basedOn: settingsFromDb, application: self)
        
        self.settings.set(applicationSettings, for: ApplicationSettings.self)
    }
    
    public func registerQueues() throws {
        // In testing environment queues are disabled.
        if self.environment == .testing {
            self.logger.warning("Queues are disabled during testing (testing environment is set).")
            self.databases.use(.sqlite(.memory), as: .sqlite)
            
            self.queues.use(.echo())
            return
        }
        
        guard let queueUrl = self.settings.getString(for: "vernissage.queueUrl") else {
            self.logger.warning("Queue URL to Redis is not configured. All queues are disabled.")
            
            self.queues.use(.echo())
            return
        }
        
        if queueUrl.isEmpty {
            self.logger.warning("Queue URL to Redis is not configured. All queues are disabled.")
            
            self.queues.use(.echo())
            return
        }

        // Activate queues.
        self.logger.info("Queues with Redis has been enabled.")
        try self.queues.use(.redis(.init(url: queueUrl, pool: .init(connectionRetryTimeout: .seconds(60)))))
        
        // Add different kind of queues.
        self.queues.add(EmailJob())
        self.queues.add(ActivityPubSharedInboxJob())
        self.queues.add(ActivityPubUserInboxJob())
        self.queues.add(ActivityPubUserOutboxJob())
        
        // Run a worker in the same process.
        try self.queues.startInProcessJobs(on: .default)
        try self.queues.startInProcessJobs(on: .emails)
        try self.queues.startInProcessJobs(on: .apUserInbox)
        try self.queues.startInProcessJobs(on: .apUserOutbox)
        try self.queues.startInProcessJobs(on: .apSharedInbox)
        
        // Run scheduled jobs in process.
        try self.queues.startScheduledJobs()
    }
    
    private func configurePostgres(connectionUrl: URLComponents) throws {
        guard let connectionUrlUser = connectionUrl.user else {
            throw DatabaseConnectionError.userNameNotSpecified
        }

        guard let connectionUrlPassword = connectionUrl.password else {
            throw DatabaseConnectionError.passwordNotSpecified
        }

        guard let connectionUrlHost = connectionUrl.host else {
            throw DatabaseConnectionError.hostNotSpecified
        }

        guard let connectionUrlPort = connectionUrl.port else {
            throw DatabaseConnectionError.portNotSpecified
        }

        let databaseName = connectionUrl.path.deletingPrefix("/")
        if databaseName.isEmpty {
            throw DatabaseConnectionError.databaseNotSpecified
        }

        let configuration = SQLPostgresConfiguration(hostname: connectionUrlHost,
                                                     port: connectionUrlPort,
                                                     username: connectionUrlUser,
                                                     password: connectionUrlPassword,
                                                     database: databaseName,
                                                     tls: .disable)

        self.logger.info("Connecting to host: '\(connectionUrlHost)', port: '\(connectionUrlPort)', user: '\(connectionUrlUser)', database: '\(databaseName)'.")
        self.databases.use(.postgres(configuration: configuration), as: .psql)
    }
    
    private func initEmailSettings() async throws {
        let hostName = try await self.services.settingsService.get(.emailHostname, on: self)
        let port = try await self.services.settingsService.get(.emailPort, on: self)
        let userName = try await self.services.settingsService.get(.emailUserName, on: self)
        let password = try await self.services.settingsService.get(.emailPassword, on: self)
        let secureMethod = try await self.services.settingsService.get(.emailSecureMethod, on: self)
        
        self.services.emailsService.setServerSettings(on: self,
                                                      hostName: hostName,
                                                      port: port,
                                                      userName: userName,
                                                      password: password,
                                                      secureMethod: secureMethod)
    }
}
