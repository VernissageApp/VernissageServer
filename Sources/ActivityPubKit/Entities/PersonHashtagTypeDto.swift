//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public enum PersonHashtagTypeDto: String {
    case hashtag = "Hashtag"
    case emoji = "Emoji"
}

extension PersonHashtagTypeDto: Codable { }