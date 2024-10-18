//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Vapor
import UniformTypeIdentifiers

extension String {
    var host: String {
        return URLComponents(string: self)?.host ?? ""
    }
    
    var fileName: String {
        return String(self.split(separator: "/").last ?? "")
    }
    
    var pathExtension: String? {
        let uri = URI(string: self)
        guard let fileExtension = uri.path.split(separator: ".").last else {
            return nil
        }
        
        return String(fileExtension)
    }
    
    var mimeType: String? {
        guard let pathExtension else {
            return nil
        }
        
        return UTType(filenameExtension: pathExtension)?.preferredMIMEType
    }
}
