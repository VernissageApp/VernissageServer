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
import SotoS3

extension Application {

    /// Called before your application initializes.
    public func configure() async throws {
        // Snowflakes id's generator have to be set up at the start of the application.
        initSnowflakesGenerator()
        
        // Configure default JSON encoder/decoder used to build responses.
        configureJsonCoders()
        
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
        
        // Register schedulers.
        try registerSchedulers()
        
        // Set up email settings.
        try await initEmailSettings()
        
        // Configure S3 support.
        configureS3()
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
        try self.register(collection: ActivityPubActorsController())
        try self.register(collection: ActivityPubSharedController())

        // Configure NodeInfo controller.
        try self.register(collection: NodeInfoController())
        
        // Instance information.
        try self.register(collection: InstanceController())
        
        // Configure API controllers.
        try self.register(collection: UsersController())
        try self.register(collection: AccountController())
        try self.register(collection: RegisterController())
        try self.register(collection: RolesController())
        try self.register(collection: IdentityController())
        try self.register(collection: SettingsController())
        try self.register(collection: AuthenticationClientsController())
        try self.register(collection: SearchController())
        try self.register(collection: AvatarsController())
        try self.register(collection: HeadersController())
        try self.register(collection: AttachmentsController())
        try self.register(collection: CountriesController())
        try self.register(collection: LocationsController())
        try self.register(collection: StatusesController())
        try self.register(collection: RelationshipsController())
        try self.register(collection: FollowRequestsController())
        try self.register(collection: TimelinesController())
        try self.register(collection: NotificationsController())
        try self.register(collection: InvitationsController())
        try self.register(collection: CategoriesController())
        try self.register(collection: ReportsController())
        try self.register(collection: TrendingController())
        try self.register(collection: LicensesController())
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
        let publicFolderPath = self.directory.publicDirectory
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
        self.migrations.add(User.CreateUsers())
        self.migrations.add(RefreshToken.CreateRefreshTokens())
        self.migrations.add(Setting.CreateSettings())
        self.migrations.add(Role.CreateRoles())
        self.migrations.add(UserRole.CreateUserRoles())
        self.migrations.add(Event.CreateEvents())
        self.migrations.add(AuthClient.CreateAuthClients())
        self.migrations.add(ExternalUser.CreateExternalUsers())
        self.migrations.add(Follow.CreateFollows())
        self.migrations.add(InstanceBlockedDomain.CreateInstanceBlockedDomains())
        self.migrations.add(UserBlockedDomain.CreateUserBlockedDomains())
        self.migrations.add(Localizable.CreateLocalizables())
        self.migrations.add(Invitation.CreateInvitations())
        self.migrations.add(Country.CreateCountries())
        self.migrations.add(Location.CreateLocations())
        
        self.migrations.add(User.UsersHeaderField())
        self.migrations.add(FlexiField.CreateFlexiFields())
        self.migrations.add(UserHashtag.CreateUserHashtag())
        
        self.migrations.add(Status.CreateStatuses())
        
        self.migrations.add(FileInfo.CreateFileInfos())
        self.migrations.add(Attachment.CreateAttachments())
        self.migrations.add(Exif.CreateExif())

        self.migrations.add(User.AddSharedInboxUrl())
        self.migrations.add(Follow.AddActivityIdToFollows())
        self.migrations.add(User.AddUserInboxUrl())
        self.migrations.add(Event.AddUserAgent())
        self.migrations.add(User.ChangeBioLength())
        self.migrations.add(User.CreateQueryNormalized())
        
        self.migrations.add(UserStatus.CreateUserStatuses())
        self.migrations.add(Status.CreateActivityPubColumns())
        self.migrations.add(StatusHashtag.CreateStatusHashtags())
        self.migrations.add(StatusMention.CreateStatusMentions())
        
        self.migrations.add(Rule.CreateRules())
        self.migrations.add(Status.CreateReblogColumn())
        self.migrations.add(Status.CreateCounters())
        self.migrations.add(Status.CreateApplicationColumn())
        
        self.migrations.add(StatusFavourite.CreateStatusFavourites())
        self.migrations.add(StatusBookmark.CreateStatusBookmarks())
        
        self.migrations.add(Notification.CreateNotifications())
        self.migrations.add(Category.CreateCategories())
        self.migrations.add(CategoryHashtag.CreateCategoryHashtags())
        self.migrations.add(Status.CreateCategoryColumn())
        
        self.migrations.add(UserMute.CreateUserMutes())
        self.migrations.add(Report.CreateReports())
        self.migrations.add(UserStatus.CreateUserStatusTypeColumn())
        
        self.migrations.add(TrendingStatus.CreateTrendingStatuses())
        self.migrations.add(TrendingUser.CreateTrendingUsers())
        self.migrations.add(TrendingHashtag.CreateTrendingHashtags())
        self.migrations.add(StatusHashtag.AddUniqueIndex())
        self.migrations.add(Category.CreateNameNormalized())
        self.migrations.add(FeaturedStatus.CreateFeaturedStatuses())
        self.migrations.add(NotificationMarker.CreateNotificationMarkers())
        
        self.migrations.add(License.CreateLicenses())
        self.migrations.add(Attachment.AddLicense())
        self.migrations.add(User.CreateLastLoginDate())
        
        try await self.autoMigrate()
    }

    public func initCacheConfiguration() async throws {
        let settingsFromDb = try await self.services.settingsService.get(on: self.db)
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
        
        // Activate redis (for distributed cache).
        self.redis.configuration = try RedisConfiguration(url: queueUrl, tlsConfiguration: nil, pool: .init(connectionRetryTimeout: .seconds(60)))

        // Activate queues.
        self.logger.info("Queues and Redis has been enabled.")
        try self.queues.use(.redis(.init(url: queueUrl, pool: .init(connectionRetryTimeout: .seconds(60)))))
        
        // Add different kind of queues.
        self.queues.add(EmailJob())
        self.queues.add(UrlValidatorJob())
        self.queues.add(UserDeleterJob())
        
        self.queues.add(StatusSenderJob())
        self.queues.add(StatusDeleterJob())
        self.queues.add(StatusRebloggerJob())
        self.queues.add(StatusUnrebloggerJob())

        self.queues.add(ActivityPubSharedInboxJob())
        self.queues.add(ActivityPubUserInboxJob())
        self.queues.add(ActivityPubUserOutboxJob())
        
        self.queues.add(ActivityPubFollowRequesterJob())
        self.queues.add(ActivityPubFollowResponderJob())
        
        // Run a worker in the same process.
        try self.queues.startInProcessJobs(on: .default)

        try self.queues.startInProcessJobs(on: .emails)
        try self.queues.startInProcessJobs(on: .urlValidator)
        try self.queues.startInProcessJobs(on: .userDeleter)

        try self.queues.startInProcessJobs(on: .statusSender)
        try self.queues.startInProcessJobs(on: .statusDeleter)
        try self.queues.startInProcessJobs(on: .statusReblogger)
        try self.queues.startInProcessJobs(on: .statusUnreblogger)

        try self.queues.startInProcessJobs(on: .apSharedInbox)
        try self.queues.startInProcessJobs(on: .apUserInbox)
        try self.queues.startInProcessJobs(on: .apUserOutbox)
        
        try self.queues.startInProcessJobs(on: .apFollowRequester)
        try self.queues.startInProcessJobs(on: .apFollowResponder)
    }
    
    private func registerSchedulers() throws {
        // During testing we shouldn't run any background jobs.
        if self.environment == .testing {
            return
        }

        // Schedule different jobs.
        self.queues.schedule(ClearAttachmentsJob()).hourly().at(15)
        self.queues.schedule(TrendingJob()).hourly().at(30)
        
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
        let hostName = try await self.services.settingsService.get(.emailHostname, on: self.db)
        let port = try await self.services.settingsService.get(.emailPort, on: self.db)
        let userName = try await self.services.settingsService.get(.emailUserName, on: self.db)
        let password = try await self.services.settingsService.get(.emailPassword, on: self.db)
        let secureMethod = try await self.services.settingsService.get(.emailSecureMethod, on: self.db)
        
        self.services.emailsService.setServerSettings(on: self,
                                                      hostName: hostName,
                                                      port: port,
                                                      userName: userName,
                                                      password: password,
                                                      secureMethod: secureMethod)
    }
    
    private func configureS3() {
        // In testing environment queues are disabled.
        if self.environment == .testing {
            self.logger.warning("S3 object storage is disabled during testing (testing environment is set).")
            return
        }
        
        let appplicationSettings = self.settings.cached

        guard let s3Address = appplicationSettings?.s3Address else {
            self.logger.warning("S3 object storage address is not set (local folder will be used).")
            return
        }
        
        guard let s3AccessKeyId = appplicationSettings?.s3AccessKeyId else {
            self.logger.warning("S3 object storage access key is not set (local folder will be used).")
            return
        }
        
        guard let s3SecretAccessKey = appplicationSettings?.s3SecretAccessKey else {
            self.logger.warning("S3 object storage secret access key is not set (local folder will be used).")
            return
        }
        
        guard let s3Bucket = appplicationSettings?.s3Bucket else {
            self.logger.warning("S3 object storage bucket name is not set (local folder will be used).")
            return
        }
        
        self.logger.info("Attachment media files will saved into S3 object storage: '\(s3Address)', bucket: '\(s3Bucket)'.")
        let awsClient = AWSClient(
            credentialProvider: .static(accessKeyId: s3AccessKeyId, secretAccessKey: s3SecretAccessKey),
            httpClientProvider: .shared(self.http.client.shared),
            logger: self.logger
        )

        self.objectStorage.client = awsClient
        
        if let s3Region = appplicationSettings?.s3Region {
            self.objectStorage.s3 = S3(client: awsClient, region: .init(rawValue: s3Region))
        } else {
            self.objectStorage.s3 = S3(client: awsClient, endpoint: s3Address)
        }
    }
    
    private func configureJsonCoders() {
        // Create a new JSON encoder/decoder that uses unix-timestamp dates
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .customISO8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601
        
        // Override the global encoder used for the `.json` media type
        ContentConfiguration.global.use(encoder: encoder, for: .json)
        ContentConfiguration.global.use(decoder: decoder, for: .json)
    }
}