//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Basic constants used in the system.
public final class Constants {
    public static let name = "Vernissage"
    public static let version = "1.0.0-buildx"
    public static let applicationName = "\(Constants.name) \(Constants.version)"
    public static let userAgent = "(\(Constants.name)/\(Constants.version))"
    public static let requestMetadata = "Request body"
    public static let twoFactorTokenHeader = "X-Auth-2FA"
    public static let xsrfTokenHeader = "X-XSRF-TOKEN"
    public static let imageQuality = 85
    public static let accessTokenName = "access-token"
    public static let refreshTokenName = "refresh-token"
    public static let xsrfTokenName = "xsrf-token"
    public static let isMachineTrustedName = "is-machine-trusted"

    public static let jrdJsonContentType: HTTPMediaType = .init(type: "application", subType: "jrd+json", parameters: ["charset": "utf-8"])
    public static let xrdXmlContentType: HTTPMediaType = .init(type: "application", subType: "xrd+xml", parameters: ["charset": "utf-8"])
    public static let activityJsonContentType: HTTPMediaType = .init(type: "application", subType: "activity+json", parameters: ["charset": "utf-8"])
}
