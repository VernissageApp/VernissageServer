//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Testing
import Foundation

@Suite("Dictionary operators tests")
struct DictionaryOperatorsTests {
    
    @Test("Dictionary should be concatenated.")
    func dictionatyShouldBeConcatenated() async throws {
        // Arrange.
        let dict1 = ["1k": "1v"]
        let dict2 = ["2k": "2v"]
        
        // Act.
        let dict = dict1 + dict2
        
        // Assert.
        #expect(dict.count == 2)
    }
    
    @Test("Dictionary should be concatenated with one operator.")
    func dictionatyShouldBeConcatenatedWithOneOperator() async throws {
        // Arrange.
        var dict = ["1k": "1v"]
        
        // Act.
        dict += ["2k": "2v"]
        
        // Assert.
        #expect(dict.count == 2)
    }
    
    @Test("Dictionary should be concatenated with sequence.")
    func dictionatyShouldBeConcatenatedWithSequence() async throws {
        // Arrange.
        var dict = [5: 2]
        
        // Act.
        dict += [(1, 3)]
        
        // Assert.
        #expect(dict.count == 2)
    }
}
