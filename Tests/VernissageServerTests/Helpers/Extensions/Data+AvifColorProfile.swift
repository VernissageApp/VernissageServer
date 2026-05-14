//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

extension Data {
    /// Returns AVIF color profile type from `colr` box payload (`nclx`, `rICC`, `prof`).
    /// This is enough for verifying whether `uploadHdr` preserved HDR color profile signaling.
    func avifColorProfileType() -> String? {
        guard self.count >= 16 else {
            return nil
        }

        let colr = [UInt8]("colr".utf8)
        let knownProfileTypes = Set(["nclx", "rICC", "prof"])
        let bytes = [UInt8](self)

        var index = 4
        while index + 8 <= bytes.count {
            if bytes[index] == colr[0],
               bytes[index + 1] == colr[1],
               bytes[index + 2] == colr[2],
               bytes[index + 3] == colr[3] {
                let profileStart = index + 4
                guard profileStart + 3 < bytes.count else {
                    return nil
                }

                let profileTypeBytes = bytes[profileStart...(profileStart + 3)]
                let profileType = String(decoding: profileTypeBytes, as: UTF8.self)
                if knownProfileTypes.contains(profileType) {
                    return profileType
                }
            }

            index += 1
        }

        return nil
    }
}
