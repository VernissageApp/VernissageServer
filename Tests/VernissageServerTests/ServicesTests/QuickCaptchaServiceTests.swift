//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing
import Queues

@Suite("QuickCaptchaService")
struct QuickCaptchaServiceTests {

    var application: Application!
    
    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }
    
    @Test("Quick captcha have to be created successfully.")
    func quickCaptchaHaveToBeCreatedSuccessfully() async throws {
        // Arrange.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        let key = String.createRandomString(length: 16)
        
        // Act.
        let binaryData = try? await application.services.quickCaptchaService.generate(key: key, on: queueContext.executionContext)
        
        // Assert.
        let quickCaptcha = try? await application.getQuickCaptcha(key: key)
        #expect(binaryData != nil, "Image binary data have to be created.")
        #expect(quickCaptcha != nil, "Quick captcha information have to be created in database.")
    }
    
    @Test("Validation should return true for correct data.")
    func validationShouldReturnTrueForCorrectData() async throws {
        // Arrange.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        let key = String.createRandomString(length: 16)
        _ = try await application.createQuickCaptcha(key: key, text: "ABCDEF")
        let token = "\(key)/ABCDEF"
        
        // Act.
        let result = try? await application.services.quickCaptchaService.validate(token: token, on: queueContext.executionContext)
        
        // Assert.
        #expect(result == true, "Validation should return true")
    }
    
    @Test("Validation should return false for incorrect key.")
    func validationShouldReturnFalseForIncorrectKey() async throws {
        // Arrange.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        let key = String.createRandomString(length: 16)
        _ = try await application.createQuickCaptcha(key: key, text: "ABCDEF")
        let token = "dejgnrujfnbgjruy/ABCDEF"
        
        // Act.
        let result = try? await application.services.quickCaptchaService.validate(token: token, on: queueContext.executionContext)
        
        // Assert.
        #expect(result == false, "Validation should return false")
    }
    
    @Test("Validation should return false for incorrect text.")
    func validationShouldReturnFalseForIncorrectText() async throws {
        // Arrange.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        let key = String.createRandomString(length: 16)
        _ = try await application.createQuickCaptcha(key: key, text: "ABCDEF")
        let token = "\(key)/ABCDEf"
        
        // Act.
        let result = try? await application.services.quickCaptchaService.validate(token: token, on: queueContext.executionContext)
        
        // Assert.
        #expect(result == false, "Validation should return false")
    }
}
