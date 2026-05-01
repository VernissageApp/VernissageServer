//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
@testable import ActivityPubKit
import Vapor
import Testing
import Queues
import Foundation

@Suite("ActivityPubSignatureService", .serialized)
struct ActivityPubSignatureServiceTests {
    var application: Application!

    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }

    @Test
    func `Signature validation should fail when signature actor does not match payload actor`() async throws {
        // Arrange.
        let payloadActor = try await application.createUser(userName: "signaturepayloadactor", generateKeys: true)
        let targetUser = try await application.createUser(userName: "signaturepayloadtarget", generateKeys: true)
        let signatureActor = try await application.createUser(userName: "signaturesigneractor", generateKeys: true)
        let context = self.executionContext()

        let request = try ActivityPubRequestFactory.signedMoveRequest(payloadActorId: payloadActor.activityPubProfile,
                                                                      targetActorId: targetUser.activityPubProfile,
                                                                      signatureActorId: signatureActor.activityPubProfile,
                                                                      signaturePrivateKey: signatureActor.privateKey!,
                                                                      requestPath: "/shared/inbox",
                                                                      requestHost: "localhost",
                                                                      moveId: 1337)

        // Act / Assert.
        do {
            try await application.services.activityPubSignatureService.validateSignature(activityPubRequest: request, on: context)
            Issue.record("validateSignature should fail when signature and payload actors are different.")
        } catch let error as ActivityPubError {
            #expect(error == .signatureActorDoesNotMatchPayloadActor(signatureActor: signatureActor.activityPubProfile, payloadActor: payloadActor.activityPubProfile))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `Signature validation should fail when signature header is missing`() async throws {
        // Arrange.
        let sourceUser = try await application.createUser(userName: "missingsignaturesource", generateKeys: true)
        let targetUser = try await application.createUser(userName: "missingsignaturetarget", generateKeys: true)
        let context = self.executionContext()

        let request = try ActivityPubRequestFactory.followRequest(sourceUser: sourceUser, targetUser: targetUser, followId: 1338)
        var headersWithoutSignature = request.headers
        headersWithoutSignature.removeValue(forKey: "signature")
        let requestWithoutSignature = ActivityPubRequestFactory.requestByReplacingHeaders(request: request, headers: headersWithoutSignature)

        // Act / Assert.
        do {
            try await application.services.activityPubSignatureService.validateSignature(activityPubRequest: requestWithoutSignature, on: context)
            Issue.record("validateSignature should fail when signature header is missing.")
        } catch let error as ActivityPubError {
            #expect(error == .missingSignatureHeader)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `Signature validation should fail when keyId is missing in signature header`() async throws {
        // Arrange.
        let sourceUser = try await application.createUser(userName: "missingkeyidsource", generateKeys: true)
        let targetUser = try await application.createUser(userName: "missingkeyidtarget", generateKeys: true)
        let context = self.executionContext()

        let request = try ActivityPubRequestFactory.followRequest(sourceUser: sourceUser, targetUser: targetUser, followId: 1339)
        var headersWithoutKeyId = request.headers
        headersWithoutKeyId["signature"] = "headers=\"(request-target) host date digest\",algorithm=\"rsa-sha256\",signature=\"QUFBQQ==\""
        let requestWithoutKeyId = ActivityPubRequestFactory.requestByReplacingHeaders(request: request, headers: headersWithoutKeyId)

        // Act / Assert.
        do {
            try await application.services.activityPubSignatureService.validateSignature(activityPubRequest: requestWithoutKeyId, on: context)
            Issue.record("validateSignature should fail when keyId is missing in signature header.")
        } catch let error as ActivityPubError {
            #expect(error == .missingKeyIdInHeader)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func `Signature validation should fail when cryptographic signature is not valid`() async throws {
        // Arrange.
        let sourceUser = try await application.createUser(userName: "invalidsignaturesource", generateKeys: true)
        let targetUser = try await application.createUser(userName: "invalidsignaturetarget", generateKeys: true)
        let context = self.executionContext()

        let request = try ActivityPubRequestFactory.followRequest(sourceUser: sourceUser, targetUser: targetUser, followId: 1340)
        var headersWithInvalidSignature = request.headers
        headersWithInvalidSignature["signature"] = "keyId=\"\(sourceUser.activityPubProfile)#main-key\",headers=\"(request-target) host date digest\",algorithm=\"rsa-sha256\",signature=\"QUFBQQ==\""
        let requestWithInvalidSignature = ActivityPubRequestFactory.requestByReplacingHeaders(request: request, headers: headersWithInvalidSignature)

        // Act / Assert.
        do {
            try await application.services.activityPubSignatureService.validateSignature(activityPubRequest: requestWithInvalidSignature, on: context)
            Issue.record("validateSignature should fail when signature bytes are invalid.")
        } catch let error as ActivityPubError {
            #expect(error == .signatureIsNotValid)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    
    @Test
    func `Signature validation should fail when date header is too far in future`() async throws {
        // Arrange.
        let sourceUser = try await application.createUser(userName: "futuredatesource", generateKeys: true)
        let targetUser = try await application.createUser(userName: "futuredatetarget", generateKeys: true)
        let context = self.executionContext()
        
        let request = try ActivityPubRequestFactory.followRequest(sourceUser: sourceUser, targetUser: targetUser, followId: 1342)
        var headersWithFutureDate = request.headers
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        headersWithFutureDate["date"] = dateFormatter.string(from: Date.now.addingTimeInterval(600))
        
        let requestWithFutureDate = ActivityPubRequestFactory.requestByReplacingHeaders(request: request, headers: headersWithFutureDate)
        
        // Act / Assert.
        do {
            try await application.services.activityPubSignatureService.validateSignature(activityPubRequest: requestWithFutureDate, on: context)
            Issue.record("validateSignature should fail when date header is too far in future.")
        } catch let error as ActivityPubError {
            #expect(error == .badTimeWindow(headersWithFutureDate["date"] ?? ""))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
    
    @Test
    func `Signature validation should use request received time when available`() async throws {
        // Arrange.
        let sourceUser = try await application.createUser(userName: "receivedattimesource", generateKeys: true)
        let targetUser = try await application.createUser(userName: "receivedattimetarget", generateKeys: true)
        let context = self.executionContext()
        let signedAt = Date.now.addingTimeInterval(-600)
        
        let request = try ActivityPubRequestFactory.signedMoveRequest(payloadActorId: sourceUser.activityPubProfile,
                                                                      targetActorId: targetUser.activityPubProfile,
                                                                      signatureActorId: sourceUser.activityPubProfile,
                                                                      signaturePrivateKey: sourceUser.privateKey!,
                                                                      signedAt: signedAt,
                                                                      moveId: 1343)
        
        // Assert baseline: without receivedAt this request is too old.
        do {
            try await application.services.activityPubSignatureService.validateSignature(activityPubRequest: request, on: context)
            Issue.record("validateSignature should fail without receivedAt when queue delay is larger than allowed time window.")
        } catch let error as ActivityPubError {
            #expect(error == .badTimeWindow(request.headers["date"] ?? ""))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        
        // Act + Assert: with receivedAt from ingress time verification should pass.
        let requestWithReceivedAt = ActivityPubRequestFactory.requestByReplacingReceivedAt(request: request, receivedAt: signedAt)
        try await application.services.activityPubSignatureService.validateSignature(activityPubRequest: requestWithReceivedAt, on: context)
    }

    @Test
    func `Algorithm validation should fail when algorithm is not supported`() async throws {
        // Arrange.
        let sourceUser = try await application.createUser(userName: "unsupportedalgsource", generateKeys: true)
        let targetUser = try await application.createUser(userName: "unsupportedalgtarget", generateKeys: true)

        let request = try ActivityPubRequestFactory.followRequest(sourceUser: sourceUser, targetUser: targetUser, followId: 1341)
        var headersWithUnsupportedAlgorithm = request.headers
        headersWithUnsupportedAlgorithm["signature"] = "keyId=\"\(sourceUser.activityPubProfile)#main-key\",headers=\"(request-target) host date digest\",algorithm=\"ed25519\",signature=\"QUFBQQ==\""
        let requestWithUnsupportedAlgorithm = ActivityPubRequestFactory.requestByReplacingHeaders(request: request, headers: headersWithUnsupportedAlgorithm)

        // Act / Assert.
        do {
            try application.services.activityPubSignatureService.validateAlgorithm(activityPubRequest: requestWithUnsupportedAlgorithm)
            Issue.record("validateAlgorithm should fail when algorithm is not supported.")
        } catch let error as ActivityPubError {
            #expect(error == .algorithmNotSupported("ed25519"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func executionContext() -> ExecutionContext {
        let queueContext = QueueContext(queueName: .apSharedInbox,
                                        configuration: .init(),
                                        application: application,
                                        logger: application.logger,
                                        on: application.eventLoopGroup.next())
        return ExecutionContext(context: queueContext)
    }

}
