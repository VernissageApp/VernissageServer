//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct MediaExifDto {
    public let make: String?
    public let model: String?
    public let lens: String?
    public let createDate: String?
    public let focalLenIn35mmFilm: String?
    public let fNumber: String?
    public let exposureTime: String?
    public let photographicSensitivity: String?
    
    public init(
        make: String?,
        model: String?,
        lens: String?,
        createDate: String?,
        focalLenIn35mmFilm: String?,
        fNumber: String?,
        exposureTime: String?,
        photographicSensitivity: String?
    ) {
        self.make = make
        self.model = model
        self.lens = lens
        self.createDate = createDate
        self.focalLenIn35mmFilm = focalLenIn35mmFilm
        self.fNumber = fNumber
        self.exposureTime = exposureTime
        self.photographicSensitivity = photographicSensitivity
    }
}

extension MediaExifDto: Codable { }
