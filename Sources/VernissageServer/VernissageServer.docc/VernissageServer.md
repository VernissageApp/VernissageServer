# ``VernissageServer``


Application which is main API component for Vernissage photos sharing platform.

# Introduction

Welcome to the Vernissage API documentation!

Vernissage is an application for sharing your photographs with other system users. It is an application that,
thanks to the implemented ActivityPub protocol, allows you to exchange information with different systems from Fediverse,
such as Pixelfed, Mastodon and others.

![Screenshots from Vernissage Web application.](web.png)

You can use our API to access Vernissage API endpoints, which can get information on statuses,
attachments, users and more in our database.

This API documentation page was created with [DocC](https://www.swift.org/documentation/docc).

## Identity columns

All objects contains own identity columnt `id`. That column is a big int (created by algorithm similar to `Snowflakes`),
however in all JSON requests have to be send as a string.

## HTTP Headers

All requests have to contains headers.

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
- ``CategoriesController``
- ``CountriesController``
- ``FollowRequestsController``
- ``HeadersController``
- ``IdentityController``
- ``InstanceController``
- ``InvitationsController``
- ``LicensesController``
- ``LocationsController``
- ``NodeInfoController``
- ``NotificationsController``
- ``RegisterController``
- ``RelationshipsController``
- ``ReportsController``
- ``RolesController``
- ``SearchController``
- ``SettingsController``
- ``StatusesController``
- ``TimelinesController``
- ``TrendingController``
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
- ``AttachmentDto``
- ``AuthClientDto``
- ``BooleanResponseDto``
- ``CategoryDto``
- ``ChangeEmailDto``
- ``ChangePasswordRequestDto``
- ``ConfigurationAttachmentsDto``
- ``ConfigurationDto``
- ``ConfigurationStatusesDto``
- ``ConfirmEmailRequestDto``
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
- ``StatusRequestDto``
- ``StatusVisibilityDto``
- ``TemporaryAttachmentDto``
- ``TrendingStatusPeriodDto``
- ``UserDto``
- ``UserMuteRequestDto``

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
- ``UserBlockedDomainsService``
- ``UserMutesService``
- ``UsersService``

### Middlewares

- ``EventHandlerMiddleware``
- ``LoginHandlerMiddleware``
- ``GuardIsAdministratorMiddleware``
- ``GuardIsModeratorMiddleware``

### Errors

- ``AccountError``
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
- ``LoginError``
- ``OpenIdConnectError``
- ``RefreshTokenError``
- ``RegisterError``
- ``RoleError``
- ``SettingError``
- ``StatusError``
- ``StorageError``
- ``TemporaryFileError``
- ``UserError``

### Queue Background Jobs

- ``ActivityPubFollowRequesterJob``
- ``ActivityPubFollowResponderJob``
- ``ActivityPubSharedInboxJob``
- ``ActivityPubUserInboxJob``
- ``ActivityPubUserOutboxJob``
- ``EmailJob``
- ``StatusDeleterJob``
- ``StatusRebloggerJob``
- ``StatusSenderJob``
- ``StatusUnrebloggerJob``
- ``UrlValidatorJob``
- ``UserDeleterJob``

### Scheduled Background Jobs

- ``ClearAttachmentsJob``
- ``TrendingJob``

### OAuth

- ``OAuthCallback``
- ``OAuthRequest``
- ``OAuthResponse``
- ``OAuthUser``

### Database Models

- ``ApplicationSettings``
- ``Attachment``
- ``AuthClient``
- ``AuthClientType``
- ``Category``
- ``CategoryHashtag``
- ``Country``
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
- ``User``
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
