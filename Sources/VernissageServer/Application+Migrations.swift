//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension Application {

    func registerMigrations() {
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

        self.migrations.add(Attachment.AddStatusIdIndex())
        self.migrations.add(StatusHashtag.AddStatusIdIndex())
        self.migrations.add(StatusMention.AddStatusIdIndex())
        self.migrations.add(StatusEmoji.AddStatusIdIndex())
        self.migrations.add(Exif.AddAttachmentIdIndex())
        
        self.migrations.add(StatusHistory.CreateStatusHistories())
        self.migrations.add(AttachmentHistory.CreateAttachmentHistories())
        self.migrations.add(ExifHistory.CreateExifHistories())
        self.migrations.add(StatusHashtagHistory.CreateStatusHashtagHistories())
        self.migrations.add(StatusMentionHistory.CreateStatusMentionHistories())
        self.migrations.add(StatusEmojiHistory.CreateStatusEmojiHistories())
        
        self.migrations.add(Status.CreateUpdatedByUserAt())
        self.migrations.add(StatusActivityPubEvent.CreateStatusActivityPubEvents())
        self.migrations.add(StatusActivityPubEventItem.CreateStatusActivityPubEventItems())
        
        self.migrations.add(Status.CreateForeignIndexes())
        self.migrations.add(ArticleFileInfo.CreateForeignIndexes())
        self.migrations.add(ArticleRead.CreateForeignIndexes())
        self.migrations.add(Article.CreateForeignIndexes())
        self.migrations.add(ArticleVisibility.CreateForeignIndexes())
        self.migrations.add(AttachmentHistory.CreateForeignIndexes())
        self.migrations.add(Attachment.CreateForeignIndexes())
        self.migrations.add(AuthDynamicClient.CreateForeignIndexes())
        self.migrations.add(BusinessCardField.CreateForeignIndexes())
        self.migrations.add(BusinessCard.CreateForeignIndexes())
        self.migrations.add(CategoryHashtag.CreateForeignIndexes())
        self.migrations.add(Event.CreateForeignIndexes())
        self.migrations.add(ExternalUser.CreateForeignIndexes())
        self.migrations.add(FlexiField.CreateForeignIndexes())
        self.migrations.add(Invitation.CreateForeignIndexes())
        self.migrations.add(Location.CreateForeignIndexes())
        self.migrations.add(NotificationMarker.CreateForeignIndexes())
        self.migrations.add(Notification.CreateForeignIndexes())
        self.migrations.add(OAuthClientRequest.CreateForeignIndexes())
        self.migrations.add(PushSubscription.CreateForeignIndexes())
        self.migrations.add(RefreshToken.CreateForeignIndexes())
        self.migrations.add(Report.CreateForeignIndexes())
        self.migrations.add(SharedBusinessCardMessage.CreateForeignIndexes())
        self.migrations.add(SharedBusinessCard.CreateForeignIndexes())
        self.migrations.add(StatusHistory.CreateForeignIndexes())
        self.migrations.add(UserAlias.CreateForeignIndexes())
        self.migrations.add(UserBlockedDomain.CreateForeignIndexes())
        self.migrations.add(UserHashtag.CreateForeignIndexes())
        self.migrations.add(UserMute.CreateForeignIndexes())
        self.migrations.add(UserRole.CreateForeignIndexes())
        self.migrations.add(UserStatus.CreateForeignIndexes())
        
        self.migrations.add(User.AddIsSupporterField())
        self.migrations.add(User.AddIncludeInSearchEngines())
        self.migrations.add(HomeCard.CreateHomeCards())
        self.migrations.add(UserBlockedDomain.DeleteDomainUniqueIndexe())
        self.migrations.add(StatusActivityPubEvent.CreateEventContextColumn())
        self.migrations.add(UserBlockedUser.CreateUserBlockedUsers())
        self.migrations.add(Report.AddIsLocal())
        self.migrations.add(Report.AddActivityPubId())
        self.migrations.add(SuspendedServer.CreateSuspendedServers())
        self.migrations.add(StatusActivityPubEventItem.AddIsSuspendedField())
    }
}
