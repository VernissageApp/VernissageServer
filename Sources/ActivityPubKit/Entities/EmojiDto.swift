//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct EmojiDto {
    public let shortcode: String?
    public let url: String?
    public let staticUrl: String?
    public let visibleInPicker: Bool?
    
    public init(shortcode: String?, url: String?, staticUrl: String?, visibleInPicker: Bool?) {
        self.shortcode = shortcode
        self.url = url
        self.staticUrl = staticUrl
        self.visibleInPicker = visibleInPicker
    }
    
    enum CodingKeys: String, CodingKey {
        case shortcode
        case url
        case staticUrl = "static_url"
        case visibleInPicker = "visible_in_picker"
    }
}

extension EmojiDto: Codable { }
