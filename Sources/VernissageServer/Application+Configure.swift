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
        await configureS3()
                
        // Init Leaf for view rendering.
        self.views.use(.leaf)
    }

    private func initSnowflakesGenerator() {
        self.services.snowflakeService = SnowflakeService()
        self.logger.info("Snowflake id generator has been initialized with node id: '\(self.services.snowflakeService.getNodeId())'.")
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
        try self.register(collection: ActivityPubActorController())
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
        try self.register(collection: AuthenticationDynamicClientsController())
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
        try self.register(collection: BookmarksController())
        try self.register(collection: FavouritesController())
        try self.register(collection: InstanceBlockedDomainsController())
        try self.register(collection: PushSubscriptionsController())
        try self.register(collection: RulesController())
        try self.register(collection: UserAliasesController())
        try self.register(collection: HealthController())
        try self.register(collection: ErrorItemsController())
        try self.register(collection: ArchivesController())
        try self.register(collection: ExportsController())
        try self.register(collection: UserSettingsController())
        try self.register(collection: RssController())
        try self.register(collection: AtomController())
        try self.register(collection: FollowingImportsController())
        try self.register(collection: ArticlesController())
        try self.register(collection: BusinessCardsController())
        try self.register(collection: SharedBusinessCardsController())
        try self.register(collection: OAuthController())
        try self.register(collection: QuickCaptchaController())
        
        // Profile controller shuld be the last one (it registers: https://example.com/@johndoe).
        try self.register(collection: ProfileController())
    }
    
    private func registerMiddlewares() {
        // Read CORS origin from settings table.
        var corsOrigin = CORSMiddleware.AllowOriginSetting.originBased
        
        let appplicationSettings = self.settings.cached
        if let corsOriginSettig = appplicationSettings?.corsOrigin, corsOriginSettig != "" {
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
            self.logger.info("Postgres database is configured in connection string.")
            let configuration = try SQLPostgresConfiguration(url: connectionUrl)
            
            self.logger.info("Connecting to database: '\(configuration.string)'.")
            self.databases.use(.postgres(configuration: configuration), as: .psql)
            return
        }
        
        // When we have environment variable but it's not Postgres we are trying to run SQLite in file.
        self.logger.notice("SQLite file database is configured in environment variable (file: \(connectionUrl.path)).")
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
        
        self.migrations.add(DisposableEmail.CreateDisposableEmails())
        self.migrations.add(User.CreateTwoFactorEnabledField())
        self.migrations.add(TwoFactorToken.CreateTwoFactorTokens())
        
        self.migrations.add(PushSubscription.CreatePushSubscriptions())
        self.migrations.add(PushSubscription.CreateAmmountOfErrorsField())
        
        self.migrations.add(UserAlias.CreateUserAliases())
        self.migrations.add(Exif.AddFilmColumn())
        self.migrations.add(User.AddUrl())
        self.migrations.add(Exif.AddGpsCoordinates())
        self.migrations.add(Exif.AddSoftware())
        self.migrations.add(FeaturedUser.CreateFeaturedUsers())
        
        self.migrations.add(TrendingHashtag.AddAmountField())
        self.migrations.add(TrendingStatus.AddAmountField())
        self.migrations.add(TrendingUser.AddAmountField())
        self.migrations.add(FeaturedStatus.ChangeUniqueIndex())
        self.migrations.add(FeaturedUser.ChangeUniqueIndex())
        self.migrations.add(ErrorItem.CreateErrorItems())
        self.migrations.add(Attachment.AddOrginalHdrFileField())
        
        self.migrations.add(Archive.CreateArchives())
        self.migrations.add(Notification.AddMainStatus())
        self.migrations.add(Status.CreateMainReplyToStatusColumn())
        self.migrations.add(Status.AddActivityPubIdUniqueIndex())
        self.migrations.add(StatusEmoji.CreateStatusEmojis())
        self.migrations.add(Report.AddMainStatus())
        self.migrations.add(Attachment.AddOrderField())
        
        self.migrations.add(UserSetting.CreateUserSettings())
        self.migrations.add(Exif.AddFlashAndFocalLength())
        self.migrations.add(Exif.ChangeFieldsLength())
        self.migrations.add(Category.CreatePriorityColumn())
        self.migrations.add(User.AddPhotosCount())
        self.migrations.add(StatusMention.AddUserUrl())
        
        self.migrations.add(FollowingImport.CreateFollowingImport())
        self.migrations.add(FollowingImportItem.CreateFollowingImportItem())
        
        self.migrations.add(Article.CreateArticles())
        self.migrations.add(ArticleVisibility.CreateArticleVisibilities())
        self.migrations.add(ArticleRead.CreateArticleReads())
        
        self.migrations.add(BusinessCard.CreateBusinessCards())
        self.migrations.add(BusinessCardField.CreateBusinessCardFields())
        self.migrations.add(SharedBusinessCard.CreateSharedBusinessCards())
        self.migrations.add(SharedBusinessCardMessage.CreateSharedBusinessCardMessages())
        
        self.migrations.add(ArticleFileInfo.CreateArticleFileInfos())
        self.migrations.add(Article.AddMainArticleFileInfo())
        self.migrations.add(User.AddUserTypeField())
        
        self.migrations.add(User.CreatePublishedAt())
        self.migrations.add(Status.CreatePublishedAt())
        self.migrations.add(Article.AddAlternativeAuthor())
        
        self.migrations.add(AuthDynamicClient.CreateAuthDynamicClients())
        self.migrations.add(OAuthClientRequest.CreateOAuthClientRequests())

        self.migrations.add(QuickCaptcha.CreateQuickCaptchas())
        self.migrations.add(QuickCaptcha.AddFilterIndexes())

        self.migrations.add(FailedLogin.CreateFailedLogins())
                
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
            self.logger.notice("Queues are disabled during testing (testing environment is set).")
            self.databases.use(.sqlite(.memory), as: .sqlite)
            
            self.queues.use(.echo())
            return
        }
        
        guard let queueUrl = self.settings.getString(for: "vernissage.queueUrl") else {
            self.logger.notice("Queue URL to Redis is not configured. All queues are disabled.")
            
            self.queues.use(.echo())
            return
        }
        
        if queueUrl.isEmpty {
            self.logger.notice("Queue URL to Redis is not configured. All queues are disabled.")
            
            self.queues.use(.echo())
            return
        }
        
        // Activate redis (for distributed cache).
        self.redis.configuration = try RedisConfiguration(url: queueUrl,
                                                          tlsConfiguration: nil,
                                                          pool: .init(connectionRetryTimeout: .seconds(60)))

        // Activate queues.
        self.logger.info("Queues and Redis has been enabled.")
        try self.queues.use(.redis(.init(url: queueUrl, pool: .init(connectionRetryTimeout: .seconds(60)))))
        
        // Add different kind of queues.
        self.queues.add(EmailJob())
        self.queues.add(WebPushSenderJob())
        self.queues.add(UrlValidatorJob())
        self.queues.add(UserDeleterJob())
        self.queues.add(FollowingImporterJob())
        
        self.queues.add(StatusSenderJob())
        self.queues.add(StatusDeleterJob())
        self.queues.add(StatusRebloggerJob())
        self.queues.add(StatusUnrebloggerJob())
        self.queues.add(StatusFavouriterJob())
        self.queues.add(StatusUnfavouriterJob())

        self.queues.add(ActivityPubSharedInboxJob())
        self.queues.add(ActivityPubUserInboxJob())
        self.queues.add(ActivityPubUserOutboxJob())
        
        self.queues.add(ActivityPubFollowRequesterJob())
        self.queues.add(ActivityPubFollowResponderJob())
        
        // Run a worker in the same process (if queues are enabled in the environment).
        let disableQueueJobs = self.settings.getString(for: "vernissage.disableQueueJobs")
        if disableQueueJobs == nil || disableQueueJobs == "false" {
            self.logger.notice("In process queues are enabled in the configuration.")
            
            try self.queues.startInProcessJobs(on: .default)
            
            try self.queues.startInProcessJobs(on: .emails)
            try self.queues.startInProcessJobs(on: .webPush)
            try self.queues.startInProcessJobs(on: .urlValidator)
            try self.queues.startInProcessJobs(on: .userDeleter)
            try self.queues.startInProcessJobs(on: .followingImporter)
            
            try self.queues.startInProcessJobs(on: .statusSender)
            try self.queues.startInProcessJobs(on: .statusDeleter)
            try self.queues.startInProcessJobs(on: .statusReblogger)
            try self.queues.startInProcessJobs(on: .statusUnreblogger)
            try self.queues.startInProcessJobs(on: .statusFavouriter)
            try self.queues.startInProcessJobs(on: .statusUnfavouriter)
            
            try self.queues.startInProcessJobs(on: .apSharedInbox)
            try self.queues.startInProcessJobs(on: .apUserInbox)
            try self.queues.startInProcessJobs(on: .apUserOutbox)
            
            try self.queues.startInProcessJobs(on: .apFollowRequester)
            try self.queues.startInProcessJobs(on: .apFollowResponder)
        } else {
            self.logger.notice("All in process queues are disabled in the configuration.")
        }
    }
    
    private func registerSchedulers() throws {
        // During testing we shouldn't run any background jobs.
        if self.environment == .testing {
            return
        }

        // Schedule different jobs.
        self.queues.schedule(ClearAttachmentsJob()).hourly().at(15)
        self.queues.schedule(ShortPeriodTrendingJob()).hourly().at(30)
        self.queues.schedule(ClearQuickCaptchasJob()).hourly().at(52)
        
        self.queues.schedule(CreateArchiveJob()).daily().at(1, 10)
        self.queues.schedule(DeleteArchiveJob()).daily().at(2, 15)
        self.queues.schedule(LongPeriodTrendingJob()).daily().at(3, 15)
        self.queues.schedule(LocationsJob()).daily().at(4, 15)
        self.queues.schedule(ClearErrorItemsJob()).daily().at(5, 15)
        self.queues.schedule(ClearFailedLoginsJob()).daily().at(5, 30)
        
        // Purge statuses three times per hour.
        self.queues.schedule(PurgeStatusesJob()).hourly().at(5)
        self.queues.schedule(PurgeStatusesJob()).hourly().at(25)
        self.queues.schedule(PurgeStatusesJob()).hourly().at(45)
        
        // Run scheduled jobs in process.
        let disableScheduledJobs = self.settings.getString(for: "vernissage.disableScheduledJobs")
        if disableScheduledJobs == nil || disableScheduledJobs == "false" {
            self.logger.notice("In process schedulers are enabled in the configuration.")
            try self.queues.startScheduledJobs()
        } else {
            self.logger.notice("All in process schedulers are disabled in the configuration.")
        }
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
        
        let appplicationSettings = self.settings.cached

        guard let s3Address = appplicationSettings?.s3Address else {
            self.logger.notice("S3 object storage address is not set (local folder will be used).")
            return
        }
        
        guard let s3AccessKeyId = appplicationSettings?.s3AccessKeyId else {
            self.logger.notice("S3 object storage access key is not set (local folder will be used).")
            return
        }
        
        guard let s3SecretAccessKey = appplicationSettings?.s3SecretAccessKey else {
            self.logger.notice("S3 object storage secret access key is not set (local folder will be used).")
            return
        }
        
        guard let s3Bucket = appplicationSettings?.s3Bucket else {
            self.logger.notice("S3 object storage bucket name is not set (local folder will be used).")
            return
        }

        let awsClient = self.configureAwsClient(s3AccessKeyId: s3AccessKeyId, s3SecretAccessKey: s3SecretAccessKey)
        self.objectStorage.client = awsClient
        
        if let s3Region = appplicationSettings?.s3Region, s3Region.count > 0 {
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
