//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import ActivityPubKit
import Testing
import Foundation

@Suite("MediaExifDataDto date parsing")
struct MediaExifDataDtoDateTests {
    private typealias DateCase = (databaseDate: String, exifDate: String, normalizedDate: String)
    
    private let dateCases: [DateCase] = [
        ("2023-04-30T10:18:01.740Z", "2023:04:30 10:18:01", "2023-04-30T10:18:01.000Z"),
        ("2025-08-11T09:18:17.739Z", "2025:08:11 09:18:17", "2025-08-11T09:18:17.000Z"),
        ("2025-06-21T11:15:02.000Z", "2025:06:21 11:15:02", "2025-06-21T11:15:02.000Z"),
        ("2025-12-27T10:35:23.820Z", "2025:12:27 10:35:23", "2025-12-27T10:35:23.000Z")
    ]
    
    @Test
    func `createDateParsed getter should convert exif date to iso date`() throws {
        // Arrange.
        var exifData: [MediaExifDataDto] = []
        exifData.createDate = "2026:02:21 09:40:18"
        
        // Act.
        let parsedDate = exifData.createDateParsed
        
        // Assert.
        #expect(parsedDate == "2026-02-21T09:40:18.000Z")
    }
    
    @Test
    func `createDateParsed setter should convert database dates to exif format`() throws {
        for dateCase in dateCases {
            // Arrange.
            var exifData: [MediaExifDataDto] = []
            
            // Act.
            exifData.createDateParsed = dateCase.databaseDate
            
            // Assert.
            #expect(exifData.createDate == dateCase.exifDate)
        }
    }
    
    @Test
    func `createDateParsed should read back normalized iso date after roundtrip`() throws {
        for dateCase in dateCases {
            // Arrange.
            var exifData: [MediaExifDataDto] = []
            exifData.createDateParsed = dateCase.databaseDate
            
            // Act.
            let parsedDate = exifData.createDateParsed
            
            // Assert.
            #expect(parsedDate == dateCase.normalizedDate)
        }
    }
}
