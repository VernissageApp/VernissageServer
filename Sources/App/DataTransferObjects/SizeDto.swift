//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct SizeDto {
    var width: Int
    var height: Int
    var aspect: Double
}

extension SizeDto {
    init(width: Int, height: Int) {
        self.init(width: width,
                  height: height,
                  aspect: Double(width) / Double(height))
    }
}

extension SizeDto: Content { }
