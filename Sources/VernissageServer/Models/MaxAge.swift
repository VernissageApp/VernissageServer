//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

/// Max-Age cache setting for static centent served by S3 CDN: https://http.dev/cache-control.
///
/// The `public` directive is included in a server’s HTTP response to indicate that it can be stored in a shared cache.
/// Caches are not permitted to store HTTP responses that contain the HTTP Authorization header unless they are accompanied by the public directive.
///
/// The `max-age` directive is sent by a server to indicate that the HTTP response will remain fresh for a specified number of seconds after it is generated.
/// Essentially, it informs caches how long it will remain fresh. Importantly, the number of seconds indicates the period from which the content was generated,
/// as opposed to received. This means that any time spent in transit or stored in the caches of intermediaries is deducted from the allowance.
///
/// The `immutable` directive indicates a guarantee by the server that the HTTP response will not be updated while it is still fresh.
/// This can be used to avoid unnecessary conditional HTTP requests
enum MaxAge: String, Codable {
    case day = "public, max-age=86400, immutable"
    case week = "public, max-age=604800, immutable"
    case month = "public, max-age=2592000, immutable"
    case year = "public, max-age=31536000, immutable"
}
