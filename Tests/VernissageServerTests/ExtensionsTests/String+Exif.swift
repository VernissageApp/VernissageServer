//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Testing
import Foundation

@Suite("String exif tests")
struct StringExifTests {
    
    @Test
    func `Exif should not be calculated when there is no divider.`() async throws {
        // Act.
        let exifNumber = "11".calculateExifNumber()
        
        // Arrange.
        #expect(exifNumber == "11")
    }
    
    @Test
    func `Exif should not be calculated when there is two dividers.`() async throws {
        // Act.
        let exifNumber = "1/2/3".calculateExifNumber()
        
        // Arrange.
        #expect(exifNumber == nil)
    }
    
    @Test
    func `Exif should be calculated when there is one divider.`() async throws {
        // Act.
        let exifNumber = "1/2".calculateExifNumber()
        
        // Arrange.
        #expect(exifNumber == "0.5")
    }
}
