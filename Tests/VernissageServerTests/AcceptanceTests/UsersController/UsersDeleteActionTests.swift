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
    
    @Suite("Users (DELETE /users/:username)", .serialized, .tags(.users))
    struct UsersDeleteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Account should be deleted for authorized user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "zibibonjek")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "zibibonjek", password: "p@ssword"),
                to: "/users/@zibibonjek",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userFromDb = try? await User.query(on: application.db).filter(\.$userName == "zibibonjek").first()
            #expect(userFromDb == nil, "User should be deleted.")
        }
        
        @Test
        func `Account should be deleted when user is moderator`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "vorybonjek")
            let user2 = try await application.createUser(userName: "georgebonjek")
            try await application.attach(user: user2, role: Role.moderator)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "georgebonjek", password: "p@ssword"),
                to: "/users/@vorybonjek",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userFromDb = try? await User.query(on: application.db).filter(\.$userName == "zibibonjek").first()
            #expect(userFromDb == nil, "User should be deleted.")
        }
        
        @Test
        func `Account should be deleted when user is administrator`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "yorkbonjek")
            let user2 = try await application.createUser(userName: "mikibonjek")
            try await application.attach(user: user2, role: Role.moderator)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "mikibonjek", password: "p@ssword"),
                to: "/users/@yorkbonjek",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userFromDb = try? await User.query(on: application.db).filter(\.$userName == "zibibonjek").first()
            #expect(userFromDb == nil, "User should be deleted.")
        }
        
        @Test
        func `Account should be deleted with statuses for authorized user`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "ygorbonjek")
            let (_, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note #hastag @ygorbonjek", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "ygorbonjek", password: "p@ssword"),
                to: "/users/@ygorbonjek",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userFromDb = try? await User.query(on: application.db).filter(\.$userName == "ygorbonjek").first()
            #expect(userFromDb == nil, "User should be deleted.")
        }
        
        @Test
        func `Account should be deleted with statuses and events for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "brian1bonjek")
            let user2 = try await application.createUser(userName: "brian2bonjek")
            let attachment = try await application.createAttachment(user: user2)
            let status = try await application.createStatus(user: user2, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user2.requireID(), type: .create)
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user1.requireID(), type: .announce)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "brian1bonjek", password: "p@ssword"),
                to: "/users/@brian1bonjek",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userFromDb = try? await User.query(on: application.db).filter(\.$userName == "brian1bonjek").first()
            #expect(userFromDb == nil, "User should be deleted.")
            
            let statusActivityPubEvents = try await application.getStatusActivityPubEvents(userId: user1.requireID())
            #expect(statusActivityPubEvents.count == 0, "Status ActivityPub events should be deleted")
        }
        
        @Test
        func `Account should be deleted with articles and main article file info for authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "articleownerbonjek")
            let article = try await application.createArticle(
                userId: user.requireID(),
                title: "Test article",
                body: "Test body",
                visibility: .signInHome
            )
            let articleFileInfo = try await application.createArticleFileInfo(
                articleId: article.requireID(),
                fileName: "article-main.jpg",
                width: 1024,
                heigth: 768
            )
            article.$mainArticleFileInfo.id = try articleFileInfo.requireID()
            try await article.save(on: application.db)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "articleownerbonjek", password: "p@ssword"),
                to: "/users/@articleownerbonjek",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userFromDb = try? await User.query(on: application.db).filter(\.$userName == "articleownerbonjek").first()
            #expect(userFromDb == nil, "User should be deleted.")
            
            let articlesCount = try await Article.query(on: application.db)
                .filter(\.$user.$id == user.requireID())
                .count()
            #expect(articlesCount == 0, "Articles should be deleted.")

            let articleFileInfosCount = try await ArticleFileInfo.query(on: application.db)
                .filter(\.$article.$id == article.requireID())
                .count()
            #expect(articleFileInfosCount == 0, "Article file infos should be deleted.")

            let articleVisibilitiesCount = try await ArticleVisibility.query(on: application.db)
                .filter(\.$article.$id == article.requireID())
                .count()
            #expect(articleVisibilitiesCount == 0, "Article visibilities should be deleted.")
        }
        
        @Test
        func `Account should be deleted with business card and shared business cards for authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "businesscardownerbonjek")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Test business card")
            
            _ = try await application.createSharedBusinessCard(
                businessCardId: businessCard.requireID(),
                title: "Share 1",
                thirdPartyName: "Partner 1"
            )
            _ = try await application.createSharedBusinessCard(
                businessCardId: businessCard.requireID(),
                title: "Share 2",
                thirdPartyName: "Partner 2"
            )
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "businesscardownerbonjek", password: "p@ssword"),
                to: "/users/@businesscardownerbonjek",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userFromDb = try? await User.query(on: application.db).filter(\.$userName == "businesscardownerbonjek").first()
            #expect(userFromDb == nil, "User should be deleted.")
            
            let businessCardsCount = try await BusinessCard.query(on: application.db)
                .filter(\.$user.$id == user.requireID())
                .count()
            #expect(businessCardsCount == 0, "Business cards should be deleted.")
            
            let sharedBusinessCardsCount = try await SharedBusinessCard.query(on: application.db)
                .filter(\.$businessCard.$id == businessCard.requireID())
                .count()
            #expect(sharedBusinessCardsCount == 0, "Shared business cards should be deleted.")
        }
        
        @Test
        func `Account should be deleted with shared business card messages for authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "sharedmessagesownerbonjek")
            let otherUser = try await application.createUser(userName: "sharedmessagesotherbonjek")
            let businessCard = try await application.createBusinessCard(userId: user.requireID(), title: "Main business card")
            let sharedBusinessCard = try await application.createSharedBusinessCard(
                businessCardId: businessCard.requireID(),
                title: "Shared card",
                thirdPartyName: "Partner"
            )
            
            let message1Id = await ApplicationManager.shared.generateId()
            let message1 = SharedBusinessCardMessage(
                id: message1Id,
                sharedBusinessCardId: try sharedBusinessCard.requireID(),
                userId: try user.requireID(),
                message: "Owner message"
            )
            try await message1.save(on: application.db)
            
            let message2Id = await ApplicationManager.shared.generateId()
            let message2 = SharedBusinessCardMessage(
                id: message2Id,
                sharedBusinessCardId: try sharedBusinessCard.requireID(),
                userId: try otherUser.requireID(),
                message: "Third party message"
            )
            try await message2.save(on: application.db)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "sharedmessagesownerbonjek", password: "p@ssword"),
                to: "/users/@sharedmessagesownerbonjek",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userFromDb = try? await User.query(on: application.db).filter(\.$userName == "sharedmessagesownerbonjek").first()
            #expect(userFromDb == nil, "User should be deleted.")

            let sharedBusinessCardsCount = try await SharedBusinessCard.query(on: application.db)
                .filter(\.$businessCard.$id == businessCard.requireID())
                .count()
            #expect(sharedBusinessCardsCount == 0, "Shared business cards should be deleted.")

            let sharedBusinessCardMessagesCount = try await SharedBusinessCardMessage.query(on: application.db)
                .filter(\.$sharedBusinessCard.$id == sharedBusinessCard.requireID())
                .count()
            #expect(sharedBusinessCardMessagesCount == 0, "Shared business card messages should be deleted.")
        }
        
        @Test
        func `Account should be deleted with oauth requests and following imports for authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "deleteoauthownerbonjek")
            let userId = try user.requireID()
            
            let authDynamicClient = try await application.createAuthDynamicClient(
                clientName: "Delete OAuth client",
                redirectUris: ["https://client.example/callback"],
                grantTypes: [.authorizationCode],
                responseTypes: [.code],
                userId: userId
            )
            
            let oauthClientRequestId = await ApplicationManager.shared.generateId()
            let oauthClientRequest = OAuthClientRequest(
                id: oauthClientRequestId,
                authDynamicClientId: try authDynamicClient.requireID(),
                userId: userId,
                csrfToken: "csrf-token",
                redirectUri: "https://client.example/callback",
                scope: "read profile",
                state: "state-token",
                nonce: "nonce-token"
            )
            try await oauthClientRequest.save(on: application.db)
            
            let followingImport = try await application.createFollwingImport(
                userId: userId,
                accounts: ["one@example.com", "two@example.com"]
            )
            let followingImportId = try followingImport.requireID()
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "deleteoauthownerbonjek", password: "p@ssword"),
                to: "/users/@deleteoauthownerbonjek",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userFromDb = try? await User.query(on: application.db).filter(\.$userName == "deleteoauthownerbonjek").first()
            #expect(userFromDb == nil, "User should be deleted.")
            
            let authDynamicClientsCount = try await AuthDynamicClient.query(on: application.db)
                .filter(\.$user.$id == userId)
                .count()
            #expect(authDynamicClientsCount == 0, "Auth dynamic clients should be deleted.")
            
            let oauthClientRequestsCount = try await OAuthClientRequest.query(on: application.db)
                .filter(\.$id == oauthClientRequestId)
                .count()
            #expect(oauthClientRequestsCount == 0, "OAuth client requests should be deleted.")
            
            let followingImportsCount = try await FollowingImport.query(on: application.db)
                .filter(\.$user.$id == userId)
                .count()
            #expect(followingImportsCount == 0, "Following imports should be deleted.")
            
            let followingImportItemsCount = try await FollowingImportItem.query(on: application.db)
                .filter(\.$followingImport.$id == followingImportId)
                .count()
            #expect(followingImportItemsCount == 0, "Following import items should be deleted.")
        }

        @Test
        func `Account should be deleted and movedTo references should be cleared`() async throws {
            // Arrange.
            let userToDelete = try await application.createUser(userName: "movedtoreference1")
            let referencingUser = try await application.createUser(userName: "movedtoreference2")
            referencingUser.$movedTo.id = try userToDelete.requireID()
            try await referencingUser.save(on: application.db)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "movedtoreference1", password: "p@ssword"),
                to: "/users/@movedtoreference1",
                method: .DELETE
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let deletedUser = try await application.getUser(id: userToDelete.requireID())
            #expect(deletedUser == nil, "User should be deleted.")

            let referencingUserFromDb = try await application.getUser(id: referencingUser.requireID())
            #expect(referencingUserFromDb?.$movedTo.id == nil, "movedTo reference should be cleared.")
        }
        
        @Test
        func `Account should not be deleted if user is not authorized`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "victoriabonjek")
            
            // Act.
            let response = try await application
                .sendRequest(to: "/users/@victoriabonjek", method: .DELETE)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test
        func `Account should not deleted when user tries to delete not his account`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "martabonjek")
            
            _ = try await application.createUser(userName: "kingabonjek",
                                                 email: "kingabonjek@testemail.com",
                                                 name: "Kinga Bonjek")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "martabonjek", password: "p@ssword"),
                to: "/users/@kingabonjek",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test
        func `Not found should be returned if account not exists`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "henrybonjek")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "henrybonjek", password: "p@ssword"),
                to: "/users/@notexists",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should forbidden (403).")
        }
    }
}
