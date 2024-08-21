# ``VernissageServer``


Application which is main API component for Vernissage photos sharing platform.

## Introduction

Welcome to the Vernissage API documentation!

Vernissage is an application for sharing your photographs with other system users. It is an application that,
thanks to the implemented ActivityPub protocol, allows you to exchange information with different systems from Fediverse,
such as Pixelfed, Mastodon and others.

![Screenshots from Vernissage Web application.](web.png)

You can use our API to access Vernissage API endpoints, which can get information on statuses,
attachments, users and more in our database.

This API documentation page was created with [DocC](https://www.swift.org/documentation/docc).

## Architecture

The Vernissage platform consists of three main components: API, Web and Proxy.
The API and Web run at the same URL, in order for the web traffic to be directed
to the appropriate application, a proxy is needed (e.g. Nginx), which will redirect
the request to the appropriate application based on the request headers.

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

Messages returned by API are always in english. However during user registration there is an property `locale`.
That property is saved in the user profile, and thanks to this property communication in user can be done.
For example emails are send with choosen language.

Default in the system we can find two languages: `en_US`, `pl_PL`. More titles and translations can be added by system administrator.

### Featured

@Links(visualStyle: detailedGrid) {
    - <doc:HostVernissageServer>
    - <doc:HostVernissageWeb>
}

## Topics

### Essentials

- <doc:HostVernissageServer>
- <doc:HostVernissageWeb>
- <doc:BuildDocumentation>

### Controllers

- ``AccountController``
- ``ActivityPubActorsController``
- ``ActivityPubSharedController``
- ``AttachmentsController``
- ``AuthenticationClientsController``
- ``AvatarsController``
- ``BookmarksController``
- ``CategoriesController``
- ``CountriesController``
- ``FavouritesController``
- ``FollowRequestsController``
- ``HeadersController``
- ``IdentityController``
- ``InstanceBlockedDomainsController``
- ``InstanceController``
- ``InvitationsController``
- ``LicensesController``
- ``LocationsController``
- ``NodeInfoController``
- ``NotificationsController``
- ``PushSubscriptionsController``
- ``RegisterController``
- ``RelationshipsController``
- ``ReportsController``
- ``RolesController``
- ``RulesController``
- ``SearchController``
- ``SettingsController``
- ``StatusesController``
- ``TimelinesController``
- ``TrendingController``
- ``UserAliasesController``
- ``UsersController``
- ``WellKnownController``

### Data Transfer Objects

- ``AccessTokenDto``
- ``ActivityPubFollowRequestDto``
- ``ActivityPubFollowRespondDto``
- ``ActivityPubRequestDto``
- ``ActivityPubRequestMethod``
- ``ActivityPubRequestPath``
- ``ActivityPubUnreblogDto``
- ``AttachmentDescriptionDto``
- ``AttachmentDto``
- ``AuthClientDto``
- ``AttachmentHashtagDto``
- ``BooleanResponseDto``
- ``CategoryDto``
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
- ``ExifDto``
- ``ExternalLoginRequestDto``
- ``FileInfoDto``
- ``FlexiFieldDto``
- ``ForgotPasswordConfirmationRequestDto``
- ``ForgotPasswordRequestDto``
- ``HashtagDto``
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
- ``PaginableResultDto``
- ``PublicSettingsDto``
- ``PushSubscriptionDto``
- ``ReblogRequestDto``
- ``RefreshTokenDto``
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
- ``WebPushDto``

### Authentication

- ``UserAuthenticator``
- ``UserPayload``

### Services

- ``ActivityPubService``
- ``ActivityPubSignatureService``
- ``AuthenticationClientsService``
- ``CaptchaService``
- ``CryptoService``
- ``EmailsService``
- ``ExternalUsersService``
- ``FlexiFieldService``
- ``FollowsService``
- ``InstanceBlockedDomainsService``
- ``InvitationsService``
- ``LocalizablesService``
- ``NotificationsService``
- ``RelationshipsService``
- ``RolesService``
- ``SearchService``
- ``SettingsService``
- ``StatusesService``
- ``TemporaryFileService``
- ``TimelineService``
- ``TokensService``
- ``TrendingService``
- ``TwoFactorTokensService``
- ``OpenAIService``
- ``UserBlockedDomainsService``
- ``UserMutesService``
- ``UsersService``
- ``WebPushService``

### Middlewares

- ``EventHandlerMiddleware``
- ``LoginHandlerMiddleware``
- ``GuardIsAdministratorMiddleware``
- ``GuardIsModeratorMiddleware``

### Errors

- ``AccountError``
- ``ActionsForbiddenError``
- ``ActivityPubError``
- ``AttachmentError``
- ``AuthClientError``
- ``AvatarError``
- ``ChangePasswordError``
- ``ConfirmEmailError``
- ``CryptoError``
- ``DatabaseConnectionError``
- ``EntityForbiddenError``
- ``EntityNotFoundError``
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
- ``RefreshTokenError``
- ``RegisterError``
- ``RoleError``
- ``RuleError``
- ``SettingError``
- ``StatusError``
- ``StorageError``
- ``TemporaryFileError``
- ``TwoFactorTokenError``
- ``UserAliasError``
- ``UserError``

### Queue Background Jobs

- ``ActivityPubFollowRequesterJob``
- ``ActivityPubFollowResponderJob``
- ``ActivityPubSharedInboxJob``
- ``ActivityPubUserInboxJob``
- ``ActivityPubUserOutboxJob``
- ``EmailJob``
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
- ``TrendingJob``

### OAuth

- ``OAuthCallback``
- ``OAuthRequest``
- ``OAuthResponse``
- ``OAuthUser``

### System & Database Models

- ``AccessTokens``
- ``ApplicationSettings``
- ``Attachment``
- ``AuthClient``
- ``AuthClientType``
- ``Category``
- ``CategoryHashtag``
- ``Country``
- ``DisposableEmail``
- ``Event``
- ``EventType``
- ``Exif``
- ``ExternalUser``
- ``FeaturedStatus``
- ``FileInfo``
- ``FlexiField``
- ``Follow``
- ``InstanceBlockedDomain``
- ``Invitation``
- ``License``
- ``LinkableResult``
- ``Localizable``
- ``Location``
- ``Notification``
- ``NotificationMarker``
- ``NotificationType``
- ``PushSubscription``
- ``RefreshToken``
- ``Report``
- ``Role``
- ``Rule``
- ``Setting``
- ``SettingKey``
- ``SettingValue``
- ``Status``
- ``StatusBookmark``
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
- ``UserStatus``
- ``UserStatusType``

### Queue Drivers

- ``EchoQueuesDriver``
- ``EchoQueue``

### Other

- ``Constants``
- ``Entrypoint``
- ``Password``
