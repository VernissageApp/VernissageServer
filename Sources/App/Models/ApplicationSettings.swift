//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct ApplicationSettings {
    public let baseAddress: String
    public let domain: String
    public let isRecaptchaEnabled: Bool
    public let isRegistrationOpened: Bool
    public let recaptchaKey: String
    public let eventsToStore: [EventType]
    public let corsOrigin: String?
    
    init(baseAddress: String = "",
         domain: String = "",
         isRecaptchaEnabled: Bool = false,
         isRegistrationOpened: Bool = false,
         recaptchaKey: String = "",
         eventsToStore: String = "",
         corsOrigin: String? = nil
    ) {
        self.baseAddress = baseAddress
        self.domain = domain
        self.isRecaptchaEnabled = isRecaptchaEnabled
        self.isRegistrationOpened = isRegistrationOpened
        self.recaptchaKey = recaptchaKey
        self.corsOrigin = corsOrigin
        
        var eventsArray: [EventType] = []
        EventType.allCases.forEach {
            if eventsToStore.contains($0.rawValue) {
                eventsArray.append($0)
            }
        }
        
        self.eventsToStore = eventsArray
    }
}
