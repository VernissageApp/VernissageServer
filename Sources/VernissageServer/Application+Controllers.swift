//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension Application {

    /// Register your application's routes here.
    func registerControllers() throws {
        // Basic response.
        self.get { _ in
            return "Service is up and running!"
        }

        try registerWellKnownControllers()
        try registerActivityPubControllers()
        try registerNodeInfoControllers()
        try registerInstanceControllers()
        try registerApiControllers()
        
        // Profile controller should be the last one (it registers: https://example.com/@johndoe).
        try self.register(collection: ProfileController())
    }

    private func registerWellKnownControllers() throws {
        try self.register(collection: WellKnownController())
    }
    
    private func registerActivityPubControllers() throws {
        try self.register(collection: ActivityPubActorController())
        try self.register(collection: ActivityPubActorsController())
        try self.register(collection: ActivityPubSharedController())
    }

    private func registerNodeInfoControllers() throws {
        try self.register(collection: NodeInfoController())
    }
    
    private func registerInstanceControllers() throws {
        try self.register(collection: InstanceController())
    }
    
    private func registerApiControllers() throws {
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
        try self.register(collection: StatusActivityPubEventsController())
        try self.register(collection: UserBlockedDomainsController())
        try self.register(collection: HomeCardsController())
        try self.register(collection: UserMutesController())
        try self.register(collection: UserBlockedUsersController())
    }
}
