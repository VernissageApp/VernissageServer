//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

extension Data {
    func embeddedIccProfileDescriptionFromJpeg() -> String? {
        guard let iccProfileData = self.iccProfileDataFromJpeg() else {
            return nil
        }

        return Self.iccProfileDescription(fromIccProfileData: iccProfileData)
    }

    private func iccProfileDataFromJpeg() -> Data? {
        guard self.count > 4, self[0] == 0xFF, self[1] == 0xD8 else {
            return nil
        }

        let iccHeader = Data([0x49, 0x43, 0x43, 0x5F, 0x50, 0x52, 0x4F, 0x46, 0x49, 0x4C, 0x45, 0x00]) // ICC_PROFILE\0
        var chunks: [Int: Data] = [:]
        var chunksCount: Int?
        var index = 2

        while index + 3 < self.count {
            guard self[index] == 0xFF else {
                index += 1
                continue
            }

            var markerIndex = index + 1
            while markerIndex < self.count, self[markerIndex] == 0xFF {
                markerIndex += 1
            }

            guard markerIndex < self.count else {
                break
            }

            let marker = self[markerIndex]
            if marker == 0xD9 || marker == 0xDA {
                break
            }

            if (0xD0...0xD7).contains(marker) || marker == 0x01 {
                index = markerIndex + 1
                continue
            }

            guard markerIndex + 2 < self.count else {
                break
            }

            let length = Self.readUInt16BE(self, at: markerIndex + 1)
            guard length >= 2 else {
                break
            }

            let payloadStart = markerIndex + 3
            let payloadLength = Int(length) - 2
            guard payloadStart + payloadLength <= self.count else {
                break
            }

            if marker == 0xE2, payloadLength > 14 {
                let payload = self[payloadStart..<(payloadStart + payloadLength)]
                if payload.prefix(iccHeader.count) == iccHeader {
                    let sequence = Int(payload[payload.startIndex + 12])
                    let total = Int(payload[payload.startIndex + 13])
                    let profileChunk = Data(payload[(payload.startIndex + 14)...])
                    chunks[sequence] = profileChunk
                    chunksCount = total
                }
            }

            index = payloadStart + payloadLength
        }

        guard let total = chunksCount, total > 0, chunks.count == total else {
            return nil
        }

        var iccData = Data()
        for sequence in 1...total {
            guard let chunk = chunks[sequence] else {
                return nil
            }

            iccData.append(chunk)
        }

        return iccData
    }

    private static func iccProfileDescription(fromIccProfileData data: Data) -> String? {
        guard data.count >= 132 else {
            return nil
        }

        let tagsCount = Int(Self.readUInt32BE(data, at: 128))
        var cursor = 132

        for _ in 0..<tagsCount {
            guard cursor + 11 < data.count else {
                return nil
            }

            let signature = String(bytes: data[cursor..<(cursor + 4)], encoding: .ascii)
            let tagOffset = Int(Self.readUInt32BE(data, at: cursor + 4))
            let tagSize = Int(Self.readUInt32BE(data, at: cursor + 8))
            cursor += 12

            guard signature == "desc", tagOffset >= 0, tagSize >= 12, tagOffset + tagSize <= data.count else {
                continue
            }

            guard let type = String(bytes: data[tagOffset..<(tagOffset + 4)], encoding: .ascii) else {
                return nil
            }

            if type == "desc" {
                let descriptionLength = Int(Self.readUInt32BE(data, at: tagOffset + 8))
                guard descriptionLength > 0 else {
                    return nil
                }

                let descriptionStart = tagOffset + 12
                let rawEnd = descriptionStart + descriptionLength
                guard rawEnd <= data.count else {
                    return nil
                }

                let descriptionData = data[descriptionStart..<rawEnd]
                let description = String(data: descriptionData, encoding: .ascii)?
                    .trimmingCharacters(in: .controlCharacters)
                return description?.isEmpty == false ? description : nil
            }

            if type == "mluc" {
                let recordsCount = Int(Self.readUInt32BE(data, at: tagOffset + 8))
                let recordSize = Int(Self.readUInt32BE(data, at: tagOffset + 12))
                guard recordsCount > 0, recordSize >= 12 else {
                    return nil
                }

                let firstRecordOffset = tagOffset + 16
                guard firstRecordOffset + 11 < data.count else {
                    return nil
                }

                let textLength = Int(Self.readUInt32BE(data, at: firstRecordOffset + 4))
                let textOffset = Int(Self.readUInt32BE(data, at: firstRecordOffset + 8))
                let textStart = tagOffset + textOffset
                let textEnd = textStart + textLength
                guard textLength > 0, textStart >= 0, textEnd <= data.count else {
                    return nil
                }

                let descriptionData = data[textStart..<textEnd]
                let description = String(data: descriptionData, encoding: .utf16BigEndian)?
                    .trimmingCharacters(in: .controlCharacters)
                return description?.isEmpty == false ? description : nil
            }
        }

        return nil
    }

    private static func readUInt16BE(_ data: Data, at index: Int) -> UInt16 {
        UInt16(data[index]) << 8 | UInt16(data[index + 1])
    }

    private static func readUInt32BE(_ data: Data, at index: Int) -> UInt32 {
        UInt32(data[index]) << 24
        | UInt32(data[index + 1]) << 16
        | UInt32(data[index + 2]) << 8
        | UInt32(data[index + 3])
    }
}
