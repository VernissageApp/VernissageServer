import Vapor

extension Application {
    public var services: Services {
        .init(application: self)
    }

    public struct Services {
        let application: Application
    }
}
