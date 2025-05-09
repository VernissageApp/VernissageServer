//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ArticleFileInfoDto {
    var url: String
    var width: Int
    var height: Int
    var aspect: Double
}

extension ArticleFileInfoDto {
    init(url: String, width: Int, height: Int) {
        self.init(url: url,
                  width: width,
                  height: height,
                  aspect: Double(width) / Double(height))
    }
}

extension ArticleFileInfoDto: Content { }
