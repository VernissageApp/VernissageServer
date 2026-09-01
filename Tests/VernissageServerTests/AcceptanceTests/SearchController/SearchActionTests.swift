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
    
    @Suite("Search (GET /search)", .serialized, .tags(.search))
    struct SearchActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Search result should be returned when local account has been specidfied`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "trondfinder")
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "trondfinder", password: "p@ssword"),
                to: "/search?query=admin",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.users != nil, "Users should be returned.")
            #expect((searchResultDto.users?.count ?? 0) > 0, "At least one user should be returned by the search.")
            #expect(searchResultDto.users?.first(where: { $0.userName == "admin" }) != nil, "Admin account should be returned.")
        }
        
        @Test
        func `Search result should be returned when local account has been specidfied with hostname`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "karolfinder")
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "karolfinder", password: "p@ssword"),
                to: "/search?query=admin@localhost",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.users != nil, "Users should be returned.")
            #expect((searchResultDto.users?.count ?? 0) > 0, "At least one user should be returned by the search.")
            #expect(searchResultDto.users?.first(where: { $0.userName == "admin" }) != nil, "Admin account should be returned.")
        }
        
        @Test
        func `Search result should be returned when local account has been specidfied with @ prefix`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "eliaszfinder")
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "eliaszfinder", password: "p@ssword"),
                to: "/search?query=@admin",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.users != nil, "Users should be returned.")
            #expect((searchResultDto.users?.count ?? 0) > 0, "At least one user should be returned by the search.")
            #expect(searchResultDto.users?.first(where: { $0.userName == "admin" }) != nil, "Admin account should be returned.")
        }

        @Test
        func `Search result should be returned when cached remote profile url has been specified`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "cachedremotefinder")
            let activityPubProfile = "https://remote.example/actors/cachedremote"
            let remoteUser = try await application.createUser(userName: "cachedremote", isLocal: false)
            remoteUser.url = "https://remote.example/@cachedremote"
            remoteUser.account = "cachedremote@remote.example"
            remoteUser.activityPubProfile = activityPubProfile
            remoteUser.userNameNormalized = remoteUser.userName.uppercased()
            remoteUser.accountNormalized = remoteUser.account.uppercased()
            remoteUser.activityPubProfileNormalized = remoteUser.activityPubProfile.uppercased()
            remoteUser.queryNormalized = "\(remoteUser.name?.uppercased() ?? "") \(remoteUser.userNameNormalized) \(remoteUser.accountNormalized) \(remoteUser.activityPubProfileNormalized)"
            try await remoteUser.update(on: application.db)

            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "cachedremotefinder", password: "p@ssword"),
                to: "/search?query=https%3A%2F%2Fremote.example%2Factors%2Fcachedremote&type=users",
                version: .v1,
                decodeTo: SearchResultDto.self
            )

            // Assert.
            #expect(searchResultDto.users != nil, "Users should be returned.")
            #expect(searchResultDto.users?.contains(where: { $0.activityPubProfile == activityPubProfile && $0.isLocal == false }) == true,
                    "Cached remote account should be returned from local database.")
        }
        
        @Test
        func `Search result should be returned when existing hashtag has been specidfied`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "mikifinder")
            let publicAttachment = try await application.createAttachment(user: user)
            let quietPublicAttachment = try await application.createAttachment(user: user)
            let followersAttachment = try await application.createAttachment(user: user)
            let attachments = [publicAttachment, quietPublicAttachment, followersAttachment]
            defer {
                application.clearFiles(attachments: attachments)
            }

            _ = try await application.createStatus(
                user: user,
                note: "#RipPerleTheCat",
                attachmentIds: [publicAttachment.stringId()!],
                visibility: .public
            )
            _ = try await application.createStatus(
                user: user,
                note: "#RipPerleTheCatMemorial",
                attachmentIds: [quietPublicAttachment.stringId()!],
                visibility: .quietPublic
            )
            _ = try await application.createStatus(
                user: user,
                note: "#RipPerleTheCatPrivate",
                attachmentIds: [followersAttachment.stringId()!],
                visibility: .followers
            )
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "mikifinder", password: "p@ssword"),
                to: "/search?query=%23RipPerleThe&type=hashtags",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.hashtags != nil, "Hashtags should be returned.")
            #expect(searchResultDto.hashtags?.contains(where: { $0.name == "RipPerleTheCat" && $0.amount == 1 }) == true,
                    "A hashtag assigned to a public status should be returned.")
            #expect(searchResultDto.hashtags?.contains(where: { $0.name == "RipPerleTheCatMemorial" && $0.amount == 1 }) == true,
                    "A hashtag assigned to a quiet public status should be returned.")
            #expect(searchResultDto.hashtags?.contains(where: { $0.name == "RipPerleTheCatPrivate" }) == false,
                    "A hashtag assigned only to a followers-only status should not be returned.")
        }

        @Test
        func `Hashtag search should prefer readable mixed case representation when available`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "readablehashtagfinder")
            let firstLowercaseAttachment = try await application.createAttachment(user: user)
            let secondLowercaseAttachment = try await application.createAttachment(user: user)
            let thirdLowercaseAttachment = try await application.createAttachment(user: user)
            let lowercaseAttachments = [firstLowercaseAttachment, secondLowercaseAttachment, thirdLowercaseAttachment]
            let mixedCaseAttachment = try await application.createAttachment(user: user)
            let privateMixedCaseAttachment = try await application.createAttachment(user: user)
            let attachments = lowercaseAttachments + [mixedCaseAttachment, privateMixedCaseAttachment]
            defer {
                application.clearFiles(attachments: attachments)
            }

            for attachment in lowercaseAttachments {
                _ = try await application.createStatus(
                    user: user,
                    note: "#accessibilitysearchtag",
                    attachmentIds: [attachment.stringId()!],
                    visibility: .public
                )
            }
            _ = try await application.createStatus(
                user: user,
                note: "#AccessibilitySearchTag",
                attachmentIds: [mixedCaseAttachment.stringId()!],
                visibility: .quietPublic
            )
            _ = try await application.createStatus(
                user: user,
                note: "#AccessibilitySEARCHTag",
                attachmentIds: [privateMixedCaseAttachment.stringId()!],
                visibility: .followers
            )

            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "readablehashtagfinder", password: "p@ssword"),
                to: "/search?query=accessibilitysearchtag&type=hashtags",
                version: .v1,
                decodeTo: SearchResultDto.self
            )

            // Assert.
            let hashtag = searchResultDto.hashtags?.first(where: { $0.name.caseInsensitiveCompare("accessibilitysearchtag") == .orderedSame })
            #expect(hashtag?.name == "AccessibilitySearchTag", "Hashtag search should prefer a mixed case representation.")
            #expect(hashtag?.amount == 4, "Hashtag amount should count all public case variants.")
        }

        @Test
        func `Empty hashtag search result should be returned when query is empty`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "emptyhashtagfinder")

            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "emptyhashtagfinder", password: "p@ssword"),
                to: "/search?query=&type=hashtags",
                version: .v1,
                decodeTo: SearchResultDto.self
            )

            // Assert.
            #expect(searchResultDto.hashtags != nil, "Hashtags should be returned.")
            #expect(searchResultDto.hashtags?.isEmpty == true, "Empty hashtag list should be returned.")
        }

        @Test
        func `LIKE wildcards in hashtag query should be treated as literal characters`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "wildcardhashtagfinder")
            let underscoreAttachment = try await application.createAttachment(user: user)
            let wildcardAttachment = try await application.createAttachment(user: user)
            let attachments = [underscoreAttachment, wildcardAttachment]
            defer {
                application.clearFiles(attachments: attachments)
            }

            _ = try await application.createStatus(
                user: user,
                note: "#year2024_test",
                attachmentIds: [underscoreAttachment.stringId()!],
                visibility: .public
            )
            _ = try await application.createStatus(
                user: user,
                note: "#year2024Xtest",
                attachmentIds: [wildcardAttachment.stringId()!],
                visibility: .public
            )

            // Act.
            let underscoreSearchResultDto = try await application.getResponse(
                as: .user(userName: "wildcardhashtagfinder", password: "p@ssword"),
                to: "/search?query=%23year2024_test&type=hashtags",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            let percentSearchResultDto = try await application.getResponse(
                as: .user(userName: "wildcardhashtagfinder", password: "p@ssword"),
                to: "/search?query=%25&type=hashtags",
                version: .v1,
                decodeTo: SearchResultDto.self
            )

            // Assert.
            #expect(underscoreSearchResultDto.hashtags?.contains(where: { $0.name == "year2024_test" }) == true,
                    "A literal underscore in a hashtag query should match the same underscore.")
            #expect(underscoreSearchResultDto.hashtags?.contains(where: { $0.name == "year2024Xtest" }) == false,
                    "An underscore in a hashtag query should not match an arbitrary character.")
            #expect(percentSearchResultDto.hashtags?.isEmpty == true,
                    "A percent sign in a hashtag query should not match all hashtags.")
        }
        
        @Test
        func `Search result should be returned when existing status has been specidfied`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "yorkifinder")

            let (_, attachments) = try await application.createStatuses(user: user, notePrefix: "This is wrocław photo", amount: 3)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "yorkifinder", password: "p@ssword"),
                to: "/search?query=wrocław&type=statuses",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.statuses != nil, "Hashtags should be returned.")
            #expect((searchResultDto.statuses?.count ?? 0) >= 3, "At least two statuses should be returned by the search.")
        }

        @Test
        func `Search result should be returned when cached remote status url has been specified`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "cachedstatusfinder")
            let remoteUser = try await application.createUser(userName: "cachedstatusauthor", isLocal: false)
            remoteUser.url = "http://remote.example/@cachedstatusauthor"
            remoteUser.account = "cachedstatusauthor@remote.example"
            remoteUser.activityPubProfile = "http://remote.example/actors/cachedstatusauthor"
            remoteUser.userNameNormalized = remoteUser.userName.uppercased()
            remoteUser.accountNormalized = remoteUser.account.uppercased()
            remoteUser.activityPubProfileNormalized = remoteUser.activityPubProfile.uppercased()
            remoteUser.queryNormalized = "\(remoteUser.name?.uppercased() ?? "") \(remoteUser.userNameNormalized) \(remoteUser.accountNormalized) \(remoteUser.activityPubProfileNormalized)"
            try await remoteUser.update(on: application.db)

            let activityPubUrl = "http://remote.example/@cachedstatusauthor/cached-status"
            let status = Status(id: await ApplicationManager.shared.generateId(),
                                isLocal: false,
                                userId: try remoteUser.requireID(),
                                note: "Cached remote status",
                                activityPubId: "http://remote.example/actors/cachedstatusauthor/statuses/cached-status",
                                activityPubUrl: activityPubUrl,
                                application: nil,
                                categoryId: nil,
                                visibility: .public,
                                publishedAt: Date())
            try await status.save(on: application.db)

            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/search?query=http%3A%2F%2Fremote.example%2F%40cachedstatusauthor%2Fcached-status&type=statuses",
                version: .v1,
                decodeTo: SearchResultDto.self
            )

            // Assert.
            #expect(searchResultDto.statuses != nil, "Statuses should be returned.")
            #expect(searchResultDto.statuses?.contains(where: { $0.activityPubUrl == activityPubUrl && $0.isLocal == false }) == true,
                    "Cached remote status should be returned from local database.")
        }

        @Test
        func `Search result should be returned when existing status has different letter case`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "casefinder")

            let (_, attachments) = try await application.createStatuses(user: user, notePrefix: "Mixed CASE note", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }

            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "casefinder", password: "p@ssword"),
                to: "/search?query=mixed%20case&type=statuses",
                version: .v1,
                decodeTo: SearchResultDto.self
            )

            // Assert.
            #expect(searchResultDto.statuses?.contains(where: { $0.note?.contains("Mixed CASE note") == true }) == true,
                    "Status should be returned by case-insensitive search.")
        }
        
        @Test
        func `Empty search result should be returned when local account has not found`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "ronaldfinder")
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "ronaldfinder", password: "p@ssword"),
                to: "/search?query=notfounded",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.users != nil, "Users should be returned.")
            #expect((searchResultDto.users?.count ?? 0) == 0, "Empty list should be returned.")
        }
        
        @Test
        func `Empty search result should be returned when query has not been specified`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "filipfinder")
            
            // Act.
            let searchResultDto = try await application.getResponse(
                as: .user(userName: "filipfinder", password: "p@ssword"),
                to: "/search?query=",
                version: .v1,
                decodeTo: SearchResultDto.self
            )
            
            // Assert.
            #expect(searchResultDto.users != nil, "Users should be returned.")
            #expect((searchResultDto.users?.count ?? 0) == 0, "Empty list should be returned.")
        }
        
        @Test
        func `Search results should not be returned when query is not specified`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "vikifinder")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "vikifinder", password: "p@ssword"),
                to: "/search",
                method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        }
        
        @Test
        func `Search results should not be returned when user is not authorized`() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/search?query=admin", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
