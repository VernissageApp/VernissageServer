//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ArticleFileInfoDto {
    var id: String
    var url: String
    var width: Int
    var height: Int
    var aspect: Double
}

extension ArticleFileInfoDto {
    init(id: String, url: String, width: Int, height: Int) {
        self.init(id: id,
                  url: url,
                  width: width,
                  height: height,
                  aspect: Double(width) / Double(height))
    }
}

extension ArticleFileInfoDto: Content { }
