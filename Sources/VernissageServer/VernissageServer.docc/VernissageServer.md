# ``VernissageServer``

Vernissage is a photo-sharing platform built for photographers, designed to seamlessly exchange content across
the fediverse - offering powerful features you won’t find anywhere else.

@Metadata {
    @DisplayName("Vernissage")
    @TitleHeading("Documentation")
}

## Introduction

Welcome to the Vernissage documentation!

Vernissage is an application designed for sharing photographs with other users within the system.
By leveraging the implemented ActivityPub protocol, Vernissage facilitates the exchange of information
with various systems across the Fediverse, including Pixelfed, Mastodon, and others.

![Screenshots from Vernissage Web application.](web.png)

You can utilize our API to access Vernissage’s endpoints, which allow you to retrieve information on statuses,
attachments, users, and more within our database.

This API documentation page was created with [DocC](https://www.swift.org/documentation/docc).

## Architecture

The Vernissage platform consists of three main components: API, Web and Proxy.
The API and Web run at the same URL, in order for the web traffic to be directed
to the appropriate application, a proxy is needed (e.g. Nginx), which will redirect
the request to the appropriate application based on the request headers or url.

![Screenshots from Vernissage Web application.](full-architecture.png)

## Database identity columns

All database objects contains own identity columnt `id`. That column is a big int (created by algorithm similar to `Snowflakes`),
however in all JSON requests have to be send as a string.

## API HTTP Headers

All requests the the VernissageServer (API) have to contains below headers.

Name         | Value            |
-------------| -----------------|
Content-Type | application/json |

## Supported languages

Messages returned by the API are always in English. However, during user registration, there is a locale
property that is stored in the user profile. This property enables communication with the user in their
selected language. For instance, emails are sent in the chosen language.

By default, the system includes two languages: en_US and pl_PL. Additional languages and translations
can be added by the system administrator.

### Featured

@Links(visualStyle: detailedGrid) {
    - <doc:HostVernissageServer>
    - <doc:HostVernissageWeb>
}

## Topics

### Essentials

- <doc:HostVernissageServer>
- <doc:HostVernissageWeb>
- <doc:DockerContainers>
- <doc:BuildDocumentation>
- <doc:ActivityPub>
- <doc:OAuthClientAutorization>
- <doc:WebFinger>
- <doc:HttpSecurity>
- <doc:ContentFeeds>

### Controllers

Below is a list of all controllers available in the system. Each controller exposes endpoints that
can be used by external applications (including other ActivityPub servers as well as client applications).
Every action performed in the system must go through these endpoints. Some are public, some require
a secure HTTP signature, and some are only accessible to registered users of a specific Vernissage instance.

- ``AccountController``
- ``ActivityPubActorController``
- ``ActivityPubActorsController``
- ``ActivityPubSharedController``
- ``ArchivesController``
- ``ArticlesController``
- ``AtomController``
- ``AttachmentsController``
- ``AuthenticationClientsController``
- ``AuthenticationDynamicClientsController``
- ``AvatarsController``
- ``BookmarksController``
- ``BusinessCardsController``
- ``CategoriesController``
- ``CountriesController``
- ``ErrorItemsController``
- ``ExportsController``
- ``FavouritesController``
- ``FollowingImportsController``
- ``FollowRequestsController``
- ``HeadersController``
- ``HealthController``
- ``IdentityController``
- ``InstanceBlockedDomainsController``
- ``InstanceController``
- ``InvitationsController``
- ``LicensesController``
- ``LocationsController``
- ``NodeInfoController``
- ``NotificationsController``
- ``OAuthController``
- ``ProfileController``
- ``PushSubscriptionsController``
- ``QuickCaptchaController``
- ``RegisterController``
- ``RelationshipsController``
- ``ReportsController``
- ``RolesController``
- ``RulesController``
- ``RssController``
- ``SearchController``
- ``SettingsController``
- ``SharedBusinessCardsController``
- ``StatusesController``
- ``TimelinesController``
- ``TrendingController``
- ``UserAliasesController``
- ``UsersController``
- ``UserSettingsController``
- ``WellKnownController``

### Data Transfer Objects

In many cases, exchanging information through the endpoints exposed by the controllers requires passing objects.
The list below contains definitions of the objects used for communication with Vernissage.

- ``AccessTokenDto``
- ``ActivityPubFollowRequestDto``
- ``ActivityPubFollowRespondDto``
- ``ActivityPubRequestDto``
- ``ActivityPubRequestMethod``
- ``ActivityPubRequestPath``
- ``ActivityPubUnreblogDto``
- ``AttachmentDescriptionDto``
- ``ArticleDto``
- ``ArticleFileInfoDto``
- ``ArticleVisibilityDto``
- ``ArchiveDto``
- ``ArchiveStatusDto``
- ``AttachmentDto``
- ``AuthClientDto``
- ``AttachmentHashtagDto``
- ``BooleanResponseDto``
- ``BusinessCardAvatarDto``
- ``BusinessCardDto``
- ``BusinessCardFieldDto``
- ``CategoryDto``
- ``CategoryHashtagDto``
- ``ChangeEmailDto``
- ``ChangePasswordRequestDto``
- ``ConfigurationAttachmentsDto``
- ``ConfigurationDto``
- ``ConfigurationStatusesDto``
- ``ConfirmEmailRequestDto``
- ``ContentWarningDto``
- ``CountryDto``
- ``EmailAddressDto``
- ``EmailDto``
- ``EmailSecureMethodDto``
- ``ErrorItemDto``
- ``ErrorItemSourceDto``
- ``ExifDto``
- ``ExternalLoginRequestDto``
- ``FileInfoDto``
- ``FlexiFieldDto``
- ``FollowingImportDto``
- ``FollowingImportItemDto``
- ``FollowingImportItemStatusDto``
- ``FollowingImportStatusDto``
- ``ForgotPasswordConfirmationRequestDto``
- ``ForgotPasswordRequestDto``
- ``HashtagDto``
- ``HealthDto``
- ``InstanceBlockedDomainDto``
- ``InstanceDto``
- ``InstanceStatisticsDto``
- ``InvitationDto``
- ``LicenseDto``
- ``LinkableParams``
- ``LinkableResultDto``
- ``LocationDto``
- ``LocationFileDto``
- ``LocationsJobDto``
- ``LoginRequestDto``
- ``MetadataDto``
- ``NotificationDto``
- ``NotificationTypeDto``
- ``NotificationsCountDto``
- ``OAuthAuthenticateCallbackDto``
- ``OAuthAuthenticateParametersDto``
- ``OAuthAuthorizePageDto``
- ``OAuthErrorCodeDto``
- ``OAuthErrorDto``
- ``OAuthGrantTypeDto``
- ``OAuthResponseTypeDto``
- ``OAuthTokenEndpointAuthMethodDto``
- ``OAuthTokenParamteresDto``
- ``OAuthTokenResponseDto``
- ``PaginableResultDto``
- ``PublicSettingsDto``
- ``PushSubscriptionDto``
- ``ReblogRequestDto``
- ``RefreshTokenDto``
- ``RegisterOAuthClientErrorCodeDto``
- ``RegisterOAuthClientErrorDto``
- ``RegisterOAuthClientRequestDto``
- ``RegisterOAuthClientResponseDto``
- ``RegisterUserDto``
- ``RelationshipDto``
- ``ReportDto``
- ``ReportRequestDto``
- ``ResendEmailConfirmationDto``
- ``RoleDto``
- ``RuleDto``
- ``SearchResultDto``
- ``SearchTypeDto``
- ``SettingsDto``
- ``SharedBusinessCardDto``
- ``SharedBusinessCardMessageDto``
- ``SharedBusinessCardUpdateRequestDto``
- ``SimpleRuleDto``
- ``StatusContextDto``
- ``StatusDeleteJobDto``
- ``StatusDto``
- ``StatusUnfavouriteJobDto``
- ``StatusRequestDto``
- ``StatusVisibilityDto``
- ``TemporaryAttachmentDto``
- ``TrendingStatusPeriodDto``
- ``TwoFactorTokenDto``
- ``UserAliasDto``
- ``UserDto``
- ``UserMuteRequestDto``
- ``UserSettingDto``
- ``UserTypeDto``
- ``WebPushDto``

### Authentication

- ``UserAuthenticator``
- ``UserPayload``
- ``XsrfTokenValidatorMiddleware``

### Services

- ``ActivityPubService``
- ``ActivityPubSignatureService``
- ``ArchivesService``
- ``ArticlesService``
- ``AtomService``
- ``AuthenticationClientsService``
- ``AuthenticationDynamicClientsService``
- ``BusinessCardsService``
- ``CaptchaService``
- ``CryptoService``
- ``EmailsService``
- ``ErroItemsService``
- ``ExternalUsersService``
- ``FlexiFieldService``
- ``FollowingImportsService``
- ``FollowsService``
- ``InstanceBlockedDomainsService``
- ``InvitationsService``
- ``LocalizablesService``
- ``LocationsService``
- ``NotificationsService``
- ``OpenAIService``
- ``PurgeStatusesService``
- ``QuickCaptchaService``
- ``RelationshipsService``
- ``RolesService``
- ``RssService``
- ``SearchService``
- ``SettingsService``
- ``SnowflakeService``
- ``StatusesService``
- ``TemporaryFileService``
- ``TimelineService``
- ``TokensService``
- ``TrendingService``
- ``TwoFactorTokensService``
- ``UserBlockedDomainsService``
- ``UserMutesService``
- ``UsersService``
- ``WebPushService``

### Middlewares

- ``CacheControlMiddleware``
- ``EventHandlerMiddleware``
- ``LoginHandlerMiddleware``
- ``GuardIsAdministratorMiddleware``
- ``GuardIsModeratorMiddleware``
- ``SecurityHeadersMiddleware``

### Errors

- ``AccountError``
- ``ActionsForbiddenError``
- ``ActivityPubError``
- ``AttachmentError``
- ``ArchiveError``
- ``ArticleError``
- ``AuthClientError``
- ``AvatarError``
- ``CategoryError``
- ``ChangePasswordError``
- ``ConfirmEmailError``
- ``CryptoError``
- ``EntityForbiddenError``
- ``EntityNotFoundError``
- ``ErrorItemError``
- ``ExportsError``
- ``FollowImportError``
- ``FollowRequestError``
- ``ForgotPasswordError``
- ``HeaderError``
- ``InvitationError``
- ``LocationError``
- ``LocalizedTerminateError``
- ``LoginError``
- ``OpenAIError``
- ``OpenIdConnectError``
- ``PushSubscriptionError``
- ``QuickCaptchaError``
- ``RefreshTokenError``
- ``RegisterError``
- ``RoleError``
- ``RuleError``
- ``SettingError``
- ``SharedBusinessCardError``
- ``StatusError``
- ``StorageError``
- ``TemporaryFileError``
- ``TwoFactorTokenError``
- ``UserAliasError``
- ``UserError``
- ``XsrfValidationError``

### Queue Background Jobs

- ``ActivityPubFollowRequesterJob``
- ``ActivityPubFollowResponderJob``
- ``ActivityPubSharedInboxJob``
- ``ActivityPubUserInboxJob``
- ``ActivityPubUserOutboxJob``
- ``EmailJob``
- ``FollowingImporterJob``
- ``StatusDeleterJob``
- ``StatusFavouriterJob``
- ``StatusUnfavouriterJob``
- ``StatusRebloggerJob``
- ``StatusSenderJob``
- ``StatusUnrebloggerJob``
- ``UrlValidatorJob``
- ``UserDeleterJob``
- ``WebPushSenderJob``

### Scheduled Background Jobs

- ``ClearAttachmentsJob``
- ``ClearErrorItemsJob``
- ``ClearQuickCaptchasJob``
- ``CreateArchiveJob``
- ``DeleteArchiveJob``
- ``LocationsJob``
- ``LongPeriodTrendingJob``
- ``PurgeStatusesJob``
- ``ShortPeriodTrendingJob``

### OAuth

- ``OAuthCallback``
- ``OAuthRequest``
- ``OAuthResponse``
- ``OAuthUser``

### System & Database Models

- ``AccessTokens``
- ``ApplicationSettings``
- ``Attachment``
- ``Article``
- ``ArticleFileInfo``
- ``ArticleRead``
- ``ArticleVisibility``
- ``ArticleVisibilityType``
- ``Archive``
- ``ArchiveStatus``
- ``AuthClient``
- ``AuthDynamicClient``
- ``AuthClientType``
- ``BusinessCard``
- ``BusinessCardField``
- ``Category``
- ``CategoryHashtag``
- ``Country``
- ``DisposableEmail``
- ``ErrorItem``
- ``ErrorItemSource``
- ``Event``
- ``EventType``
- ``Exif``
- ``ExternalUser``
- ``FeaturedUser``
- ``FeaturedStatus``
- ``FileInfo``
- ``FlexiField``
- ``Follow``
- ``FollowingImport``
- ``FollowingImportItem``
- ``FollowingImportItemStatus``
- ``FollowingImportStatus``
- ``InstanceBlockedDomain``
- ``Invitation``
- ``ImageOrientation``
- ``License``
- ``LinkableResult``
- ``Localizable``
- ``Location``
- ``Notification``
- ``NotificationMarker``
- ``NotificationType``
- ``OAuthClientRequest``
- ``MaxAge``
- ``PushSubscription``
- ``QuickCaptcha``
- ``RefreshToken``
- ``Report``
- ``Role``
- ``Rule``
- ``Setting``
- ``SettingKey``
- ``SettingValue``
- ``SharedBusinessCard``
- ``SharedBusinessCardMessage``
- ``Status``
- ``StatusBookmark``
- ``StatusEmoji``
- ``StatusFavourite``
- ``StatusHashtag``
- ``StatusMention``
- ``StatusVisibility``
- ``TrendingHashtag``
- ``TrendingPeriod``
- ``TrendingStatus``
- ``TrendingUser``
- ``TwoFactorToken``
- ``User``
- ``UserAlias``
- ``UserBlockedDomain``
- ``UserHashtag``
- ``UserMute``
- ``UserRole``
- ``UserSetting``
- ``UserStatus``
- ``UserStatusType``
- ``UserType``

### Queue Drivers

- ``EchoQueuesDriver``
- ``EchoQueue``

### Other

- ``ExecutionContext``
- ``Constants``
- ``Entrypoint``
- ``Password``
