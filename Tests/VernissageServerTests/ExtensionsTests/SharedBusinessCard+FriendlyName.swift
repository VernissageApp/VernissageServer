//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Testing
import Foundation

@Suite("SharedBusinessCard third party friendly name tests")
struct SharedBusinessCardThirdPartyFriendlyNameTests {
    
    @Test("Third party name should be returned if it's specified.")
    func thirdPartyNameShouldBeReturnedIfItsSpecified() async throws {
        // Arrange.
        let sharedBusinessCard = SharedBusinessCard(id: 1, businessCardId: 1, code: "", title: "", thirdPartyName: "John Doe", thirdPartyEmail: nil)
        
        // Act.
        let thirdPartyFriendlyName = sharedBusinessCard.thirdPartyFriendlyName
        
        // Arrange.
        #expect(thirdPartyFriendlyName == "John Doe")
    }
    
    @Test("Username from email should be returned if party name is empty and email is specified.")
    func usernameFromEmailShouldBeReturnedIfPartyNameIsEmptyAndEmailIsSpecified() async throws {
        // Arrange.
        let sharedBusinessCard = SharedBusinessCard(id: 1, businessCardId: 1, code: "", title: "", thirdPartyName: "", thirdPartyEmail: "johndoe@example.com")
        
        // Act.
        let thirdPartyFriendlyName = sharedBusinessCard.thirdPartyFriendlyName
        
        // Arrange.
        #expect(thirdPartyFriendlyName == "johndoe")
    }
    
    @Test("Nil should be returned when both third party data are empty.")
    func nilShouldBeReturnedWhenBothThirdPartyDataAreEmpty() async throws {
        // Arrange.
        let sharedBusinessCard = SharedBusinessCard(id: 1, businessCardId: 1, code: "", title: "", thirdPartyName: "", thirdPartyEmail: "")
        
        // Act.
        let thirdPartyFriendlyName = sharedBusinessCard.thirdPartyFriendlyName
        
        // Arrange.
        #expect(thirdPartyFriendlyName == nil)
    }
}
