//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Vapor
import ExtendedConfiguration

extension Application.Settings {
    var cached: ApplicationSettings? {
        return self.get(ApplicationSettings.self)
    }
}
