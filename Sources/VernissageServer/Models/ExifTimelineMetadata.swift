//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

struct ExifTimelineMetadata: Sendable {
    let make: String?
    let model: String?
    let lens: String?
    let film: String?

    init(from exif: Exif) {
        self.make = exif.make
        self.model = exif.model
        self.lens = exif.lens
        self.film = exif.film
    }
}
