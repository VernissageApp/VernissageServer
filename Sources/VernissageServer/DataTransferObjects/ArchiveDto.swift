//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ArchiveDto {
    var id: String?
    var user: UserDto
    var requestDate: Date
    var startDate: Date?
    var endDate: Date?
    var fileName: String?
    var status: ArchiveStatusDto
    var errorMessage: String?
    var createdAt: Date?
    var updatedAt: Date?
}

extension ArchiveDto {
    init(from archive: Archive, baseImagesPath: String, baseAddress: String) {
        self.init(id: archive.stringId(),
                  user: UserDto(from: archive.user, baseImagesPath: baseImagesPath, baseAddress: baseAddress),
                  requestDate: archive.requestDate,
                  startDate: archive.startDate,
                  endDate: archive.endDate,
                  fileName: ArchiveDto.getFileName(archive, baseImagesPath: baseImagesPath),
                  status: ArchiveStatusDto.from(archive.status),
                  errorMessage: archive.errorMessage,
                  createdAt: archive.createdAt,
                  updatedAt: archive.updatedAt)
    }
    
    private static func getFileName(_ archive: Archive, baseImagesPath: String) -> String? {
        guard let fileName = archive.fileName else { return nil }
        
        return baseImagesPath.finished(with: "/") + fileName
    }
}

extension ArchiveDto: Content { }
