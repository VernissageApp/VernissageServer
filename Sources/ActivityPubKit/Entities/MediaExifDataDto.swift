//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Exif data implementing FEP-ee3a: Exif metadata support.
/// More inforrmation: https://codeberg.org/fediverse/fep/src/branch/main/fep/ee3a/fep-ee3a.md
public struct MediaExifDataDto {
    public let type: String
    public let name: String
    public let value: String?

    public init(name: String, value: String) {
        self.type = "PropertyValue"
        self.name = name
        self.value = value
    }

    enum CodingKeys: String, CodingKey {
        case type
        case typeWithAtSign = "@type"
        case name
        case value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.type = try container.decodeIfPresent(String.self, forKey: .typeWithAtSign)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? "PropertyValue"
        self.name = try container.decode(String.self, forKey: .name)
        self.value = try container.decodeIfPresent(String.self, forKey: .value)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .typeWithAtSign)
        try container.encode(self.name, forKey: .name)
        try container.encodeIfPresent(self.value, forKey: .value)
    }
}

extension MediaExifDataDto: Codable { }
extension MediaExifDataDto: Sendable { }

public extension [MediaExifDataDto] {
    
    /// Tag names according to https://codeberg.org/fediverse/fep/src/branch/main/fep/ee3a/fep-ee3a.md.
    private enum ExifTags: String {
        case dateTime = "DateTime"
        case exposureTime = "ExposureTime"
        case fNumber = "FNumber"
        case flash = "Flash"
        case focalLength = "FocalLength"
        case focalLengthIn35mmFilm = "FocalLengthIn35mmFilm"
        case gpsLatitude = "GPSLatitude"
        case gpsLatitudeRef = "GPSLatitudeRef"
        case gpsLongitude = "GPSLongitude"
        case gpsLongitudeRef = "GPSLongitudeRef"
        case lensMake = "LensMake"
        case lensModel = "LensModel"
        case make = "Make"
        case model = "Model"
        case photographicSensitivity = "PhotographicSensitivity"
        case software = "Software"
        
        // Extensions.
        case film = "Film"
        case scanner = "Scanner"
        case chemistry = "Chemistry"
    }
    
    private static var exifDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }
    
    /// Device manufacturer.
    var make: String? {
        get {
            return self.first(where: { $0.name == ExifTags.make.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.make.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.make.rawValue, value: newVal))
            }
        }
    }

    /// Device model.
    var model: String? {
        get {
            return self.first(where: { $0.name == ExifTags.model.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.model.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.model.rawValue, value: newVal))
            }
        }
    }

    /// Lens manufacturer.
    var lensMake: String? {
        get {
            return self.first(where: { $0.name == ExifTags.lensMake.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.lensMake.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.lensMake.rawValue, value: newVal))
            }
        }
    }
    
    /// Lens model name.
    var lensModel: String? {
        get {
            return self.first(where: { $0.name == ExifTags.lensModel.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.lensModel.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.lensModel.rawValue, value: newVal))
            }
        }
    }
    
    /// Date and time when the media was created. Exif's DateTime tag uses the format "YYYY:MM:DD HH:MM:SS". The time is expressed in the photographer's local time zone.
    var createDate: String? {
        get {
            return self.first(where: { $0.name == ExifTags.dateTime.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.dateTime.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.dateTime.rawValue, value: newVal))
            }
        }
    }
    
    /// Date parsed from "YYYY:MM:DD HH:MM:SS" to format "2026-02-21T09:40:18.000Z" (and vice-versa).
    var createDateParsed: String? {
        get {
            guard let value = self.first(where: { $0.name == ExifTags.dateTime.rawValue })?.value else {
                return nil
            }

            if let date = Self.exifDateFormatter.date(from: value)
                ?? CustomFormatter().iso8601withFractionalSeconds().date(from: value)
                ?? CustomFormatter().iso8601().date(from: value) {
                return date.toISO8601String()
            }

            return nil
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.dateTime.rawValue }
            if let newVal {
                if let date = CustomFormatter().iso8601withFractionalSeconds().date(from: newVal)
                    ?? CustomFormatter().iso8601().date(from: newVal)
                    ?? Self.exifDateFormatter.date(from: newVal) {
                    let formattedDate = Self.exifDateFormatter.string(from: date)
                    self.append(MediaExifDataDto(name: ExifTags.dateTime.rawValue, value: formattedDate))
                }
            }
        }
    }

    /// Focal length reported by the camera.
    var focalLength: String? {
        get {
            return self.first(where: { $0.name == ExifTags.focalLength.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.focalLength.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.focalLength.rawValue, value: newVal))
            }
        }
    }
    
    /// 35 mm equivalent focal length.
    var focalLenIn35mmFilm: String? {
        get {
            return self.first(where: { $0.name == ExifTags.focalLengthIn35mmFilm.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.focalLengthIn35mmFilm.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.focalLengthIn35mmFilm.rawValue, value: newVal))
            }
        }
    }
    
    /// Aperture value expressed as an f-number (e.g., "f/1.8").
    var fNumber: String? {
        get {
            return self.first(where: { $0.name == ExifTags.fNumber.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.fNumber.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.fNumber.rawValue, value: newVal))
            }
        }
    }

    /// Exposure time (e.g., "1/100" or "4").
    var exposureTime: String? {
        get {
            return self.first(where: { $0.name == ExifTags.exposureTime.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.exposureTime.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.exposureTime.rawValue, value: newVal))
            }
        }
    }
    
    /// ISO sensitivity.
    var photographicSensitivity: String? {
        get {
            return self.first(where: { $0.name == ExifTags.photographicSensitivity.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.photographicSensitivity.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.photographicSensitivity.rawValue, value: newVal))
            }
        }
    }

    /// Description of flash usage (e.g., "Flash did not fire.").
    var flash: String? {
        get {
            return self.first(where: { $0.name == ExifTags.flash.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.flash.rawValue}
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.flash.rawValue, value: newVal))
            }
        }
    }
    
    /// Exact latitude of the photo location  (requires user consent).
    var latitude: String? {
        get {
            return self.first(where: { $0.name == ExifTags.gpsLatitude.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.gpsLatitude.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.gpsLatitude.rawValue, value: newVal))
            }
        }
    }
    
    /// Indicates whether the latitude of shooting location is north or south latitude. 'N' indicates north latitude, and 'S' is south latitude.
    var latitudeRef: String? {
        get {
            return self.first(where: { $0.name == ExifTags.gpsLatitudeRef.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.gpsLatitudeRef.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.gpsLatitudeRef.rawValue, value: newVal))
            }
        }
    }
    
    /// Exact longitude of the photo location (requires user consent).
    var longitude: String? {
        get {
            return self.first(where: { $0.name == ExifTags.gpsLongitude.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.gpsLongitude.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.gpsLongitude.rawValue, value: newVal))
            }
        }
    }
    
    /// Indicates whether the longitude of shooting location is east or west longitude. 'E' indicates east longitude, and 'W' is west longitude.
    var longitudeRef: String? {
        get {
            return self.first(where: { $0.name == ExifTags.gpsLongitudeRef.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.gpsLongitudeRef.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.gpsLongitudeRef.rawValue, value: newVal))
            }
        }
    }

    /// Editing software or firmware used.
    var software: String? {
        get {
            return self.first(where: { $0.name == ExifTags.software.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.software.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.software.rawValue, value: newVal))
            }
        }
    }

    /// Film used in analog camera.
    var film: String? {
        get {
            return self.first(where: { $0.name == ExifTags.film.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.film.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.film.rawValue, value: newVal))
            }
        }
    }
    
    /// Scanner used to digitalize analog photo.
    var scanner: String? {
        get {
            return self.first(where: { $0.name == ExifTags.scanner.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.scanner.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.scanner.rawValue, value: newVal))
            }
        }
    }
    
    /// Chemistry  used to develop analog photo.
    var chemistry: String? {
        get {
            return self.first(where: { $0.name == ExifTags.chemistry.rawValue })?.value
        }
        
        set (newVal) {
            self.removeAll { $0.name == ExifTags.chemistry.rawValue }
            if let newVal {
                self.append(MediaExifDataDto(name: ExifTags.chemistry.rawValue, value: newVal))
            }
        }
    }
}
