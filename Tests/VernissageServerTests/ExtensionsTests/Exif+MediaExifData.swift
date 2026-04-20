//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
@testable import ActivityPubKit
import Testing
import Foundation

@Suite("Exif and MediaExifData mapping")
struct ExifMediaExifDataTests {
    private typealias DateCase = (databaseDate: String, exifDate: String, normalizedDate: String)
    
    private let dateCases: [DateCase] = [
        ("2023-04-30T10:18:01.740Z", "2023:04:30 10:18:01", "2023-04-30T10:18:01.000Z"),
        ("2025-08-11T09:18:17.739Z", "2025:08:11 09:18:17", "2025-08-11T09:18:17.000Z"),
        ("2025-06-21T11:15:02.000Z", "2025:06:21 11:15:02", "2025-06-21T11:15:02.000Z"),
        ("2025-12-27T10:35:23.820Z", "2025:12:27 10:35:23", "2025-12-27T10:35:23.000Z")
    ]
    
    @Test
    func `Exif toExifData should convert database date to exif DateTime format`() throws {
        for (index, dateCase) in dateCases.enumerated() {
            // Arrange.
            let exif = try #require(Exif(id: Int64(index + 1), createDate: dateCase.databaseDate))
            exif.scanner = nil
            
            // Act.
            let exifData = exif.toExifData()
            
            // Assert.
            #expect(exifData.createDate == dateCase.exifDate)
        }
    }
    
    @Test
    func `Exif init from exifData should convert DateTime to normalized database date`() throws {
        for (index, dateCase) in dateCases.enumerated() {
            // Arrange.
            let exifData = [MediaExifDataDto(name: "DateTime", value: dateCase.exifDate)]
            
            // Act.
            let exif = try #require(Exif(id: Int64(index + 1), exifData: exifData))
            
            // Assert.
            #expect(exif.createDate == dateCase.normalizedDate)
        }
    }
    
    @Test
    func `Exif should map software film scanner and chemistry both ways`() throws {
        // Arrange.
        let exifFromDatabase = try #require(
            Exif(
                id: 1,
                software: "Darktable",
                film: "Kodak Portra 400",
                scanner: "Nikon Coolscan",
                chemistry: "C-41"
            )
        )
        
        // Act.
        let exifData = exifFromDatabase.toExifData()
        let exifFromJson = try #require(Exif(id: 2, exifData: exifData))
        
        // Assert.
        #expect(exifData.software == "Darktable")
        #expect(exifData.film == "Kodak Portra 400")
        #expect(exifData.scanner == "Nikon Coolscan")
        #expect(exifData.chemistry == "C-41")
        
        #expect(exifFromJson.software == "Darktable")
        #expect(exifFromJson.film == "Kodak Portra 400")
        #expect(exifFromJson.scanner == "Nikon Coolscan")
        #expect(exifFromJson.chemistry == "C-41")
    }
    
    @Test
    func `ExifHistory should preserve software mapping for history responses`() throws {
        // Arrange.
        let exif = try #require(
            Exif(
                id: 1,
                software: "Darktable",
                scanner: "Epson V850",
                chemistry: "ECN-2"
            )
        )
        let exifHistory = ExifHistory(id: 2, attachmentHistoryId: 3, from: exif)
        
        // Act.
        let exifData = exifHistory.toExifData()
        
        // Assert.
        #expect(exifHistory.software == "Darktable")
        #expect(exifHistory.scanner == "Epson V850")
        #expect(exifHistory.chemistry == "ECN-2")
        #expect(exifData.software == "Darktable")
        #expect(exifData.scanner == "Epson V850")
        #expect(exifData.chemistry == "ECN-2")
    }
}
