//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct MediaLocationDto {
    public let type = "Place"
    public let name: String
    public let longitude: String?
    public let latitude: String?
    public let geonameId: String?
    public let addressCountry: String?
    
    public init(geonameId: String?, name: String, longitude: String, latitude: String, countryCode: String) {
        self.geonameId = geonameId
        self.name = name
        self.longitude = longitude
        self.latitude = latitude
        self.addressCountry = countryCode
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case geonameId
        case name
        case longitude
        case latitude
        case addressCountry
    }
}

extension MediaLocationDto: Codable { }
extension MediaLocationDto: Sendable { }
