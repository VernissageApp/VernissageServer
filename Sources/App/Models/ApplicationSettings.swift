//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct ApplicationSettings {
    public let baseAddress: String
    public let domain: String
    public let emailServiceAddress: String?
    public let isRecaptchaEnabled: Bool
    public let recaptchaKey: String
    public let eventsToStore: [EventType]
    public let corsOrigin: String?
    
    init(baseAddress: String = "",
         domain: String = "",
         emailServiceAddress: String? = nil,
         isRecaptchaEnabled: Bool = false,
         recaptchaKey: String = "",
         eventsToStore: String = "",
         corsOrigin: String? = nil
    ) {
        self.baseAddress = baseAddress
        self.domain = domain
        self.emailServiceAddress = emailServiceAddress
        self.isRecaptchaEnabled = isRecaptchaEnabled
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
