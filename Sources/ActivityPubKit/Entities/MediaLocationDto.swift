//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct MediaLocationDto {
    public let geonameId: String?
    public let name: String
    public let longitude: String
    public let latitude: String
    public let countryCode: String
    public let countryName: String
    
    public init(geonameId: String?, name: String, longitude: String, latitude: String, countryCode: String, countryName: String) {
        self.geonameId = geonameId
        self.name = name
        self.longitude = longitude
        self.latitude = latitude
        self.countryCode = countryCode
        self.countryName = countryName
    }
}

extension MediaLocationDto: Codable { }
