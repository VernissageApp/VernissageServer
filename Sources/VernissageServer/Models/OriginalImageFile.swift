//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Detects the supported original format without rewriting the image.
/// Storage uses the extension for both the generated filename and Content-Type.
enum OriginalImageFile {
    static func storageFileName(for url: URL, fallbackFileName: String) throws -> String {
        let file = try FileHandle(forReadingFrom: URL(fileURLWithPath: url.path))
        defer { try? file.close() }
        let header = try file.read(upToCount: 12) ?? Data()

        if header.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "original.jpg"
        }
        if header.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return "original.png"
        }
        if header.count == 12,
           header.prefix(4) == Data("RIFF".utf8),
           header.suffix(4) == Data("WEBP".utf8) {
            return "original.webp"
        }

        return fallbackFileName
    }
}
