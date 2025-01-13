//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct CategoryDto {
    var id: String?
    var name: String
    var hashtags: [CategoryHashtagDto]?
}

extension CategoryDto {
    init(from category: Category, with hashtags: [CategoryHashtag]) {
        let hashtagDtos = hashtags.map { CategoryHashtagDto(from: $0) }
        self.init(id: category.stringId(), name: category.name, hashtags: hashtagDtos)
    }
    
    init?(from category: Category?) {
        guard let category else {
            return nil
        }

        self.init(id: category.stringId(), name: category.name)
    }
}

extension CategoryDto: Content { }
