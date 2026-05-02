//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("ActivityPubShared (POST /shared/inbox [DeleteUser])", .serialized, .tags(.shared))
    struct ActivityPubSharedDeleteUserTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Account should be deleted when all correct data has been applied`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "vikirubens", generateKeys: true, isLocal: false)
            
            let deleteTarget = ActivityPub.Users.delete(user1.activityPubProfile,
                                                        user1.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let user = try await application.getUser(id: user1.requireID())
            #expect(user == nil, "User must be deleted from local datbase.")
        }
        
        @Test
        func `Account should not be deleted when account is local`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "mikerubens", generateKeys: true, isLocal: true)
            
            let deleteTarget = ActivityPub.Users.delete(user1.activityPubProfile,
                                                        user1.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let user = try await application.getUser(id: user1.requireID())
            #expect(user != nil, "User must not be deleted from local datbase.")
        }
        
        @Test
        func `Delete acount should fail when date is outside time frame`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "trisrubens", generateKeys: true, isLocal: false)
            
            let deleteTarget = ActivityPub.Users.delete(user1.activityPubProfile,
                                                        user1.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")
            
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
            dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
            
            let dateString = dateFormatter.string(from: Date.now.addingTimeInterval(-600))
            
            var headers = deleteTarget.headers?.getHTTPHeaders() ?? HTTPHeaders()
            headers.replaceOrAdd(name: "date", value: dateString)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: headers,
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "badTimeWindow", "Error code should be equal 'badTimeWindow'.")
            #expect(errorResponse.error.reason == "ActivityPub signed request date '\(dateString)' is outside acceptable time window.")
            
            let user = try await application.getUser(id: user1.requireID())
            #expect(user != nil, "User must not be deleted from local datbase.")
        }

        @Test
        func `Remote account delete should clear movedTo references`() async throws {
            // Arrange.
            let remoteUser = try await application.createUser(userName: "movedremote1", generateKeys: true, isLocal: false)
            let localReferencingUser = try await application.createUser(userName: "movedremote2", isLocal: true)
            localReferencingUser.$movedTo.id = try remoteUser.requireID()
            try await localReferencingUser.save(on: application.db)

            let deleteTarget = ActivityPub.Users.delete(remoteUser.activityPubProfile,
                                                        remoteUser.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")

            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
                body: deleteTarget.httpBody!)

            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let deletedRemoteUser = try await application.getUser(id: remoteUser.requireID())
            #expect(deletedRemoteUser == nil, "Remote user must be deleted from local database.")

            let localReferencingUserFromDb = try await application.getUser(id: localReferencingUser.requireID())
            #expect(localReferencingUserFromDb?.$movedTo.id == nil, "movedTo reference should be cleared.")
        }

        @Test
        func `Remote account delete should remove aliases and notifications`() async throws {
            // Arrange.
            let remoteUser = try await application.createUser(userName: "deleteremote1", generateKeys: true, isLocal: false)
            let localUser = try await application.createUser(userName: "deleteremote2", isLocal: true)

            _ = try await application.createUserAlias(
                userId: remoteUser.requireID(),
                alias: "deleteremote1@other.instance",
                activityPubProfile: "https://other.instance/users/deleteremote1"
            )
            
            let notificationId = await ApplicationManager.shared.generateId()
            let notification = Notification(
                id: notificationId,
                notificationType: .follow,
                to: try localUser.requireID(),
                by: try remoteUser.requireID()
            )
            try await notification.save(on: application.db)
            _ = try await application.createNotificationMarker(user: localUser, notification: notification)

            let deleteTarget = ActivityPub.Users.delete(remoteUser.activityPubProfile,
                                                        remoteUser.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let deletedRemoteUser = try await application.getUser(id: remoteUser.requireID())
            #expect(deletedRemoteUser == nil, "Remote user must be deleted from local database.")
            
            let alias = try await UserAlias.query(on: application.db)
                .filter(\.$user.$id == remoteUser.requireID())
                .first()
            #expect(alias == nil, "Aliases for deleted remote user should be removed.")
            
            let notificationFromDb = try await Notification.query(on: application.db)
                .filter(\.$id == notificationId)
                .first()
            #expect(notificationFromDb == nil, "Notifications linked with deleted remote user should be removed.")
            
            let marker = try await NotificationMarker.query(on: application.db)
                .filter(\.$notification.$id == notificationId)
                .first()
            #expect(marker == nil, "Notification markers linked with deleted notifications should be removed.")
        }
        
        @Test
        func `Remote account delete should remove oauth requests following imports and shared card messages`() async throws {
            // Arrange.
            let remoteUser = try await application.createUser(userName: "deleteremotecomplex1", generateKeys: true, isLocal: false)
            let localUser = try await application.createUser(userName: "deleteremotecomplex2", isLocal: true)
            let remoteUserId = try remoteUser.requireID()
            
            let authDynamicClient = try await application.createAuthDynamicClient(
                clientName: "Remote OAuth client",
                redirectUris: ["https://remote.client/callback"],
                grantTypes: [.authorizationCode],
                responseTypes: [.code],
                userId: remoteUserId
            )
            let oauthClientRequestId = await ApplicationManager.shared.generateId()
            let oauthClientRequest = OAuthClientRequest(
                id: oauthClientRequestId,
                authDynamicClientId: try authDynamicClient.requireID(),
                userId: remoteUserId,
                csrfToken: "csrf",
                redirectUri: "https://remote.client/callback",
                scope: "read profile",
                state: "state",
                nonce: "nonce"
            )
            try await oauthClientRequest.save(on: application.db)
            
            let followingImport = try await application.createFollwingImport(
                userId: remoteUserId,
                accounts: ["first@example.com", "second@example.com"]
            )
            let followingImportId = try followingImport.requireID()
            
            let businessCard = try await application.createBusinessCard(userId: remoteUserId, title: "Remote card")
            let sharedBusinessCard = try await application.createSharedBusinessCard(
                businessCardId: try businessCard.requireID(),
                title: "Remote shared card",
                thirdPartyName: "Remote partner"
            )
            let messageId = await ApplicationManager.shared.generateId()
            let message = SharedBusinessCardMessage(
                id: messageId,
                sharedBusinessCardId: try sharedBusinessCard.requireID(),
                userId: try localUser.requireID(),
                message: "Remote message"
            )
            try await message.save(on: application.db)

            let deleteTarget = ActivityPub.Users.delete(remoteUser.activityPubProfile,
                                                        remoteUser.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: deleteTarget.headers?.getHTTPHeaders() ?? .init(),
                body: deleteTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let deletedRemoteUser = try await application.getUser(id: remoteUserId)
            #expect(deletedRemoteUser == nil, "Remote user must be deleted from local database.")
            
            let authDynamicClientsCount = try await AuthDynamicClient.query(on: application.db)
                .filter(\.$user.$id == remoteUserId)
                .count()
            #expect(authDynamicClientsCount == 0, "Auth dynamic clients should be removed for deleted remote user.")
            
            let oauthClientRequestsCount = try await OAuthClientRequest.query(on: application.db)
                .filter(\.$id == oauthClientRequestId)
                .count()
            #expect(oauthClientRequestsCount == 0, "OAuth client requests should be removed for deleted remote user.")
            
            let followingImportsCount = try await FollowingImport.query(on: application.db)
                .filter(\.$user.$id == remoteUserId)
                .count()
            #expect(followingImportsCount == 0, "Following imports should be removed for deleted remote user.")
            
            let followingImportItemsCount = try await FollowingImportItem.query(on: application.db)
                .filter(\.$followingImport.$id == followingImportId)
                .count()
            #expect(followingImportItemsCount == 0, "Following import items should be removed for deleted remote user.")
            
            let businessCardId = try businessCard.requireID()
            let sharedBusinessCardsCount = try await SharedBusinessCard.query(on: application.db)
                .filter(\.$businessCard.$id == businessCardId)
                .count()
            #expect(sharedBusinessCardsCount == 0, "Shared business cards should be removed for deleted remote user.")
            
            let sharedBusinessCardId = try sharedBusinessCard.requireID()
            let sharedBusinessCardMessagesCount = try await SharedBusinessCardMessage.query(on: application.db)
                .filter(\.$sharedBusinessCard.$id == sharedBusinessCardId)
                .count()
            #expect(sharedBusinessCardMessagesCount == 0, "Shared business card messages should be removed for deleted remote user.")
        }

        @Test
        func `Account should not be deleted when activity actor is not profile owner`() async throws {
            // Arrange.
            let victim = try await application.createUser(userName: "deletevictim", generateKeys: true, isLocal: false)
            let attacker = try await application.createUser(userName: "deleteattacker", generateKeys: true, isLocal: false)

            let signedRequest = try ActivityPubRequestFactory.signedDeleteUserRequest(actorId: attacker.activityPubProfile,
                                                                                       objectId: victim.activityPubProfile,
                                                                                       signaturePrivateKey: attacker.privateKey!)
            var headers = HTTPHeaders()
            for (name, value) in signedRequest.headers {
                headers.add(name: name, value: value)
            }

            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: headers,
                body: signedRequest.body)

            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")

            let victimFromDatabase = try await application.getUser(id: victim.requireID())
            #expect(victimFromDatabase != nil, "Victim account must not be deleted when actor does not match profile id.")
        }
    }
}
