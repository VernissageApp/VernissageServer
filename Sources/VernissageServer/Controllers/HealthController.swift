//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit
import SotoCore
import SotoSNS

extension HealthController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("health")
    
    func boot(routes: RoutesBuilder) throws {
        let locationsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(HealthController.uri)
        
        locationsGroup
            .grouped(EventHandlerMiddleware(.healthRead))
            .get(use: read)
    }
}

/// Exposing health status of the system components.
///
/// > Important: Base controller URL: `/api/v1/health`.
struct HealthController {
    
    /// Exposing system health status.
    ///
    /// > Important: Endpoint URL: `/api/v1/health`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/health" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "isDatabaseHealthy": true,
    ///     "isQueueHealthy": true,
    ///     "isWebPushHealthy": true,
    ///     "isStorageHealthy": true
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of countries.
    @Sendable
    func read(request: Request) async throws -> HealthDto {
        let isDatabaseHealthy = await self.isDatabaseHealthy(on: request)
        let isQueueHealthy = await self.isQueueHealthy(on: request)
        let isWebPushHealthy = await self.isWebPushHealthy(on: request)
        let isStorageHealthy = await self.isStorageHealthy(on: request)
        
        return HealthDto(isDatabaseHealthy: isDatabaseHealthy,
                         isQueueHealthy: isQueueHealthy,
                         isWebPushHealthy: isWebPushHealthy,
                         isStorageHealthy: isStorageHealthy)
    }
    
    private func isDatabaseHealthy(on request: Request) async -> Bool {
        do {
            _ = try await User.query(on: request.db).first()
            return true
        } catch {
            await request.logger.store("Database health check error.", error, on: request.application)
            return false
        }
    }
    
    private func isQueueHealthy(on request: Request) async -> Bool {
        do {
            if let _ = request.application.queues.driver as? EchoQueuesDriver {
                return true
            }

            _ = try await request.application.redis.get(key: "health-check")
            return true
        } catch {
            await request.logger.store("Redis queue health check error.", error, on: request.application)
            return false
        }
    }
    
    private func isWebPushHealthy(on request: Request) async -> Bool {
        do {
            let webPushService = request.application.services.webPushService
            _ = try await webPushService.check(on: request)
            return true
        } catch {
            await request.logger.store("WebPush service health check error.", error, on: request.application)
            return false
        }
    }
    
    private func isStorageHealthy(on request: Request) async -> Bool {
        do {
            guard let file = try await FileInfo.query(on: request.db).sort(\.$createdAt, .descending).first() else {
                return true
            }
            
            let storageService = request.application.services.storageService
            _ = try await storageService.get(fileName: file.fileName, on: request)
            
            return true
        } catch let error as S3ErrorType {
            await request.logger.store("Storage health check error.", error, on: request.application)
            return false
        } catch {
            await request.logger.store("Storage health check error.", error, on: request.application)
            return false
        }
    }
}
