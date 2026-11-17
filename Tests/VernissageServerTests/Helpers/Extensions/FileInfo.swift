//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Foundation
import Vapor

extension FileInfo {
    func storedData(on application: Application) throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: "\(application.directory.workingDirectory)/Public/storage/\(self.fileName)"))
    }
}
