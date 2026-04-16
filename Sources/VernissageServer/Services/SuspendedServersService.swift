//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

extension Application.Services {
    struct SuspendedServersServiceKey: StorageKey {
        typealias Value = SuspendedServersServiceType
    }

    var suspendedServersService: SuspendedServersServiceType {
        get {
            self.application.storage[SuspendedServersServiceKey.self] ?? SuspendedServersService()
        }
        nonmutating set {
            self.application.storage[SuspendedServersServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol SuspendedServersServiceType: Sendable {
    /// Reads suspended servers for current sending iteration.
    ///
    /// - Parameter context: Execution context.
    /// - Returns: List with suspended servers state.
    func getSnapshot(on context: ExecutionContext) async -> [SuspendedServer]

    /// Checks if request can be sent to host.
    ///
    /// - Parameters:
    ///   - host: Host name from URL.
    ///   - suspendedServers: List loaded for current iteration.
    /// - Returns: `false` when host is temporarily suspended.
    func shouldSend(to host: String?, basedOn suspendedServers: [SuspendedServer]) async -> Bool

    /// Registers connection related error for host.
    ///
    /// - Parameters:
    ///   - host: Host name from URL.
    ///   - error: Error returned during request.
    ///   - context: Execution context.
    /// - Throws: Database errors.
    func registerConnectionError(for host: String?, error: Error, on context: ExecutionContext) async throws

    /// Removes host from suspended list after successful request.
    ///
    /// - Parameters:
    ///   - host: Host name from URL.
    ///   - context: Execution context.
    /// - Throws: Database errors.
    func registerSuccess(for host: String?, on context: ExecutionContext) async throws
}

/// A service responsible for managing temporarily suspended remote servers.
actor SuspendedServersService: SuspendedServersServiceType {
    private let maxNumberOfErrors: Int
    private let suspensionPeriod: TimeInterval

    private let connectionErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .networkConnectionLost,
        .dnsLookupFailed,
        .notConnectedToInternet,
        .resourceUnavailable,
        .cannotLoadFromNetwork
    ]

    private let connectionPosixCodes: Set<Int32> = [
        ECONNREFUSED,
        ECONNRESET,
        ETIMEDOUT,
        EHOSTUNREACH,
        ENETUNREACH,
        ENETDOWN,
        ENOTCONN
    ]
    
    private let connectionErrorCodeRawValues: Set<Int>

    init(maxNumberOfErrors: Int = 10, suspensionPeriod: TimeInterval = 24 * 60 * 60) {
        self.maxNumberOfErrors = maxNumberOfErrors
        self.suspensionPeriod = suspensionPeriod
        self.connectionErrorCodeRawValues = Set(self.connectionErrorCodes.map(\.rawValue))
    }

    func getSnapshot(on context: ExecutionContext) async -> [SuspendedServer] {
        if let suspendedServers = try? await SuspendedServer.query(on: context.db).all() {
            return suspendedServers
        }

        return []
    }

    func shouldSend(to host: String?, basedOn suspendedServers: [SuspendedServer]) async -> Bool {
        guard let hostNormalized = self.normalizedHost(from: host) else {
            return true
        }

        guard let suspendedServer = suspendedServers.first(where: { $0.hostNormalized == hostNormalized }) else {
            return true
        }

        if suspendedServer.numberOfErrors < self.maxNumberOfErrors {
            return true
        }

        let retryDate = suspendedServer.lastErrorDate.addingTimeInterval(self.suspensionPeriod)
        return retryDate <= Date()
    }

    func registerConnectionError(for host: String?, error: Error, on context: ExecutionContext) async throws {
        guard let host,
              let hostNormalized = self.normalizedHost(from: host),
              self.isConnectionError(error) else {
            return
        }

        let lastErrorDate = Date()
        let suspendedServerFromDatabase = try await SuspendedServer.query(on: context.db)
            .filter(\.$hostNormalized == hostNormalized)
            .first()

        if let suspendedServerFromDatabase {
            suspendedServerFromDatabase.numberOfErrors += 1
            suspendedServerFromDatabase.lastErrorDate = lastErrorDate

            try await suspendedServerFromDatabase.save(on: context.db)
            return
        }

        let id = context.services.snowflakeService.generate()
        let newSuspendedServer = SuspendedServer(id: id,
                                              host: host,
                                              numberOfErrors: 1,
                                              lastErrorDate: lastErrorDate)
        do {
            try await newSuspendedServer.save(on: context.db)
        } catch {
            // If another service instance inserted row in parallel, update existing row.
            let existingSuspendedServer = try await SuspendedServer.query(on: context.db)
                .filter(\.$hostNormalized == hostNormalized)
                .first()

            if let existingSuspendedServer {
                existingSuspendedServer.numberOfErrors += 1
                existingSuspendedServer.lastErrorDate = lastErrorDate

                try await existingSuspendedServer.save(on: context.db)
                return
            }

            throw error
        }
    }

    func registerSuccess(for host: String?, on context: ExecutionContext) async throws {
        guard let hostNormalized = self.normalizedHost(from: host) else {
            return
        }

        let suspendedServer = try await SuspendedServer.query(on: context.db)
            .filter(\.$hostNormalized == hostNormalized)
            .first()
        
        if let suspendedServer {
            try await suspendedServer.delete(on: context.db)
        }
    }

    private func normalizedHost(from host: String?) -> String? {
        guard let host else {
            return nil
        }

        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedHost.isEmpty == false else {
            return nil
        }

        return trimmedHost.uppercased()
    }

    private func isConnectionError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return self.connectionErrorCodes.contains(urlError.code)
        }

        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain,
           self.connectionErrorCodeRawValues.contains(nsError.code) {
            return true
        }

        if nsError.domain == NSPOSIXErrorDomain,
           self.connectionPosixCodes.contains(Int32(nsError.code)) {
            return true
        }

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return self.isConnectionError(underlyingError)
        }

        return false
    }
}
