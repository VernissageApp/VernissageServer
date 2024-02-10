//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension Application {
    public var services: Services {
        .init(application: self)
    }

    public struct Services {
        let application: Application
    }
}
