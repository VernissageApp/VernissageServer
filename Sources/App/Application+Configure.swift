//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import ExtendedError
import ExtendedConfiguration
import JWT

extension Application {

    /// Called before your application initializes.
    public func configure() throws {
        // Register routes to the router.
        try routes()
        
        // Initialize configuration from file.
        try initConfiguration()
        
        // Configure database.
        try configureDatabase()
        
        // Migrate database.
        try migrateDatabase()
        
        // Seed database.
        try seedDatabase()
        
        // Read configuration from database.
        try loadConfiguration()
        
        // Register middleware.
        registerMiddlewares()
    }

    /// Register your application's routes here.
    private func routes() throws {
        // Basic response.
        self.get { req in
            return "Service is up and running!"
        }

        // Configuring controllers.
        try self.register(collection: WebfingerController())
        try self.register(collection: ActivityPubController())
        try self.register(collection: UsersController())
        try self.register(collection: AccountController())
        try self.register(collection: RegisterController())
        try self.register(collection: ForgotPasswordController())
        try self.register(collection: RolesController())
        try self.register(collection: UserRolesController())
        try self.register(collection: IdentityController())
        try self.register(collection: AuthenticationClientsController())
    }
    
    private func registerMiddlewares() {
        // Read CORS origin from settings table.
        var corsOrigin = CORSMiddleware.AllowOriginSetting.all
        
        let appplicationSettings = self.settings.get(ApplicationSettings.self)
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
    }
    
    private func initConfiguration() throws {
        self.logger.info("Init configuration for environment: \(self.environment.name)")
        
        try self.settings.load([
            .jsonFile("appsettings.json", optional: false),
            .jsonFile("appsettings.\(self.environment.name).json", optional: true),
            .jsonFile("appsettings.local.json", optional: true),
            .environmentVariables(.withPrefix("users."))
        ])
                
        self.settings.configuration.all().forEach { (key: String, value: Any) in
            self.logger.info("Configuration: \(key), value: \(value)")
        }
    }

    private func configureDatabase(clearDatabase: Bool = false) throws {
        // In testing environmebt we are using in memory database.
        if self.environment == .testing {
            self.logger.info("In memory SQLite is used during testing (testing environment is set)")
            self.databases.use(.sqlite(.memory), as: .sqlite)
            return
        }
        
        // Retrieve connection string from configuration settings.
        guard let connectionString = self.settings.getString(for: "users.connectionString") else {
            self.logger.info("In memory SQLite has been used (connection string is not set)")
            self.databases.use(.sqlite(.memory), as: .sqlite)
            return
        }
        
        // When environment variable is not configured we are using in memory database.
        guard let connectionUrl = URL(string: connectionString) else {
            self.logger.warning("In memory SQLite has been used (incorrect URL is set: \(connectionString)).")
            self.databases.use(.sqlite(.memory), as: .sqlite)
            return
        }
            
        // Configuration for Postgres.
        if connectionUrl.scheme?.hasPrefix("postgres") == true {
            self.logger.info("Postgres database is configured in environment variable (host: \(connectionUrl.host ?? ""), db: \(connectionUrl.path))")
            try self.configurePostgres(connectionUrl: connectionUrl)
            return
        }
        
        // When we have environment variable but it's not Postgres we are trying to run SQLite in file.
        self.logger.info("SQLite file database is configured in environment variable (file: \(connectionUrl.path))")
        self.databases.use(.sqlite(.file(connectionUrl.path)), as: .sqlite)
    }
    
    private func migrateDatabase() throws {
        // Configure migrations
        self.migrations.add(CreateUsers())
        self.migrations.add(CreateRefreshTokens())
        self.migrations.add(CreateSettings())
        self.migrations.add(CreateRoles())
        self.migrations.add(CreateUserRoles())
        self.migrations.add(CreateEvents())
        self.migrations.add(CreateAuthClients())
        self.migrations.add(CreateExternalUsers())
        self.migrations.add(AddSvgIconToAuthClient())
        
        try self.autoMigrate().wait()
    }

    private func loadConfiguration() throws {
        let settings = try self.services.settingsService.get(on: self).wait()
        
        guard let privateKey = settings.getString(.jwtPrivateKey)?.data(using: .ascii) else {
            throw Abort(.internalServerError, reason: "Private key is not configured in database.")
        }
        
        let rsaKey: RSAKey = try .private(pem: privateKey)
        self.jwt.signers.use(.rs512(key: rsaKey))
        
        let applicationSettings = ApplicationSettings(
            baseAddress: settings.getString(.baseAddress) ?? "http://localhost:8080/",
            domain: settings.getString(.domain) ?? "localhost",
            emailServiceAddress: settings.getString(.emailServiceAddress),
            isRecaptchaEnabled: settings.getBool(.isRecaptchaEnabled) ?? false,
            recaptchaKey: settings.getString(.recaptchaKey) ?? "",
            eventsToStore: settings.getString(.eventsToStore) ?? ""
        )
        
        self.settings.set(applicationSettings, for: ApplicationSettings.self)
    }
    
    private func configurePostgres(connectionUrl: URL) throws {
        if connectionUrl.user == nil {
            throw DatabaseConnectionError.userNameNotSpecified
        }

        if connectionUrl.password == nil {
            throw DatabaseConnectionError.passwordNotSpecified
        }

        if connectionUrl.host == nil {
            throw DatabaseConnectionError.hostNotSpecified
        }

        if connectionUrl.port == nil {
            throw DatabaseConnectionError.portNotSpecified
        }

        if connectionUrl.path.split(separator: "/").last.flatMap(String.init) == nil {
            throw DatabaseConnectionError.databaseNotSpecified
        }

        let configuration = try SQLPostgresConfiguration(url: connectionUrl)
        self.databases.use(.postgres(configuration: configuration), as: .psql)
    }
}
