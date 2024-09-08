//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Vapor
import SwiftExif

public enum ImageOrientation: String {
    
    // Top-left.
    case horizontalNormal = "1"
    
    // Top-right.
    case mirrorHorizontal = "2"

    // Bottom-right.
    case rotate180 = "3"
    
    // Bottom-left.
    case mirrorVertical = "4"
    
    // Left-top.
    case mirrorHorizontalAndRotate270CW = "5"
    
    // Right-top.
    case rotate90CW = "6"
    
    // Right-bottom.
    case mirrorHorizontalAndRotate90CW = "7"
    
    // Left-bottom.
    case rotate270CW = "8"
    
    init(fileUrl: URL, on application: Application) {
        let exifImage = SwiftExif.Image(imagePath: fileUrl)
        let exifData = exifImage.ExifRaw()
        
        guard let orientation = exifData["0"]?["Orientation"] else {
            self = .horizontalNormal
            return
        }
        
        guard let orientationEnum = ImageOrientation(rawValue: orientation) else {
            application.logger.warning("Image orientation '\(orientation)' has not been correctly identified.")

            self = .horizontalNormal
            return
        }
        
        self = orientationEnum
    }
}
