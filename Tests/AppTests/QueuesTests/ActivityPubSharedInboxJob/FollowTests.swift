//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import Queues
import ActivityPubKit
import _CryptoExtras

final class FollowTests: CustomTestCase {
    
    func testFollowShouldSuccessWhenAllCorrectDataHasBeenApplied() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "vikiurban")
        let user2 = try await User.create(userName: "rickurban")

        let activityDto = ActivityDto.follow(sourceActorId: user1.activityPubProfile, targetActorId: user2.activityPubProfile)
        let activityPubRequestDto = try ActivityPubRequestDto(cryptoService: CryptoService(),
                                                              privateKey: user1.privateKey!,
                                                              activity: activityDto,
                                                              basePath: "vernissage.photos",
                                                              version: "1.0.0",
                                                              actorId: user1.activityPubProfile)
        
        // Act.
        let queue = ActivityPubSharedInboxJob()  
        try await queue.dequeue(SharedApplication.application().getQueueContext(queueName: .apSharedInbox), activityPubRequestDto)
        
        // Assert.
        let follow = try await Follow.get(sourceId: user1.requireID(), targetId: user2.requireID())
        XCTAssertNotNil(follow, "Follow must be added to local datbase")
    }
    
    func testFollowShouldFailWhenDateIsOutsideTimeFrame() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "ronurban")
        let user2 = try await User.create(userName: "tomurban")

        let activityDto = ActivityDto.follow(sourceActorId: user1.activityPubProfile, targetActorId: user2.activityPubProfile)
        
        let singnatureBase64 = "123="
        let bodyHash = "432="
        let version = "1.0.0"
        let basePath = "localhost"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        let dateString = dateFormatter.string(from: Date.now.addingTimeInterval(-600))
        
        let headers: [String: String] = [
            "date": dateString,
            "digest": "SHA-256=\(bodyHash)",
            "content-type": "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"",
            "user-agent": "(Vernissage/\(version); +https://\(basePath)",
            "signature":
"""
keyId="\(user1.activityPubProfile)#main-key",headers="(request-target) host date digest content-type user-agent",algorithm="rsa-sha256",signature="\(singnatureBase64)"
""",
            "host": basePath
        ]
        
        let activityPubRequestDto = try ActivityPubRequestDto(activity: activityDto, headers: headers, bodyHash: bodyHash, httpMethod: .post, httpPath: .sharedInbox)
        
        // Act.
        do {
            let queue = ActivityPubSharedInboxJob()
            try await queue.dequeue(SharedApplication.application().getQueueContext(queueName: .apSharedInbox), activityPubRequestDto)
        } catch ActivityPubError.badTimeWindow(_) {
            return
        } catch {
            XCTFail("Wrong error thrown")
            return
        }

        XCTFail("Bad time window error must be thrown.")
    }
    
    func testFollowShouldFailWhenBodyHashIsWrong() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "erikurban")
        let user2 = try await User.create(userName: "yordurban")

        let activityDto = ActivityDto.follow(sourceActorId: user1.activityPubProfile, targetActorId: user2.activityPubProfile)
        
        let singnatureBase64 = "123="
        let bodyHash = "432="
        let version = "1.0.0"
        let basePath = "localhost"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        let dateString = dateFormatter.string(from: Date.now)
        
        let headers: [String: String] = [
            "date": dateString,
            "digest": "SHA-256=\(bodyHash)",
            "content-type": "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"",
            "user-agent": "(Vernissage/\(version); +https://\(basePath)",
            "signature":
"""
keyId="\(user1.activityPubProfile)#main-key",headers="(request-target) host date digest content-type user-agent",algorithm="rsa-sha256",signature="\(singnatureBase64)"
""",
            "host": basePath
        ]
        
        let activityPubRequestDto = try ActivityPubRequestDto(activity: activityDto, headers: headers, bodyHash: bodyHash, httpMethod: .post, httpPath: .sharedInbox)
        
        // Act.
        do {
            let queue = ActivityPubSharedInboxJob()
            try await queue.dequeue(SharedApplication.application().getQueueContext(queueName: .apSharedInbox), activityPubRequestDto)
        } catch ActivityPubError.signatureIsNotValid {
            return
        } catch {
            XCTFail("Wrong error thrown")
            return
        }

        XCTFail("Signature is not valid error must be thrown.")
    }
}
