//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import SwiftGD
import SwiftExif
import Foundation
import gd

extension SwiftGD.Image {

    public static func create(fileName: String, byteBuffer: ByteBuffer) -> SwiftGD.Image? {
        var byteBuffer = byteBuffer
        guard let data = byteBuffer.readData(length: byteBuffer.readableBytes) else {
            return nil
        }
        
        // Supported image file types.
        let ext = fileName.pathExtension?.lowercased() ?? "jpg"
        if ["jpg", "jpeg", "png"].contains(ext) == false {
            return nil
        }
        
        guard let image = switch ext {
        case "jpg", "jpeg":
            try? SwiftGD.Image(data: data, as: .jpg)
        case "png":
            try? SwiftGD.Image(data: data, as: .png)
        // Avif files for now supports only sRGB color profile (error: Image's color profile is not sRGB).
        // case "avif":
        //    try? SwiftGD.Image(data: data, as: .avif)
        default:
            nil
        } else {
            return try? SwiftGD.Image(data: data)
        }

        return image
    }
    
    public static func create(path: URL) -> SwiftGD.Image? {
        let fileUrl = URL(fileURLWithPath: path.absoluteString)
        guard let data = try? Data(contentsOf: fileUrl) else {
            return nil
        }

        let ext = fileUrl.pathExtension.lowercased()
        
        // Supported image file types.
        if ["jpg", "jpeg", "png"].contains(ext) == false {
            return nil
        }
        
        guard let image = switch ext {
        case "jpg", "jpeg":
            try? SwiftGD.Image(data: data, as: .jpg)
        case "png":
            try? SwiftGD.Image(data: data, as: .png)
        // Avif files for now supports only sRGB color profile (error: Image's color profile is not sRGB).
        // case "avif":
        //    try? SwiftGD.Image(data: data, as: .avif)
        default:
            nil
        } else {
            return try? SwiftGD.Image(data: data)
        }

        return image
    }
    
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

