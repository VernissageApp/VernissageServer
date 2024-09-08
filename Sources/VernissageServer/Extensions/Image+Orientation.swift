//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import SwiftGD
import SwiftExif

extension SwiftGD.Image {
    func orientation(fileUrl: URL, on application: Application) -> ImageOrientation {
        let exifImage = SwiftExif.Image(imagePath: fileUrl)
        let exifData = exifImage.Exif()
        
        guard let orientation = exifData["0"]?["Orientation"] else {
            return .horizontalNormal
        }
        
        guard let orientationEnum = ImageOrientation(rawValue: orientation) else {
            application.logger.warning("Image orientation '\(orientation)' has not been correctly identified.")
            return .horizontalNormal
        }
        
        return orientationEnum
    }
    
    func rotate(basedOn orientation: ImageOrientation) -> SwiftGD.Image? {
        switch orientation {
        case .horizontalNormal:
            return self
        case .mirrorHorizontal:
            return self.flipped(.horizontal)
        case .rotate180:
            return self.rotated(.degrees(-180))
        case .mirrorVertical:
            return self.flipped(.vertical)
        case .mirrorHorizontalAndRotate270CW:
            let rotated = self.rotated(.degrees(-90))
            return rotated?.flipped(.horizontal)
        case .rotate90CW:
            return self.rotated(.degrees(-90))
        case .mirrorHorizontalAndRotate90CW:
            let rotated = self.rotated(.degrees(-90))
            return rotated?.flipped(.vertical)
        case .rotate270CW:
            return self.rotated(.degrees(-270))
        }
    }
}
