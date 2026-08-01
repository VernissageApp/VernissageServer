//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor MockActivityPubOutgoingMigrationService: ActivityPubOutgoingMigrationServiceType {
    enum Response: Sendable {
        case success
        case httpStatus(Int)
        case connectionError
    }

    private let response: Response
    private let responsesByHost: [String: Response]
    private var sentFollowIds: [Int64] = []
    private var sentMoveIds: [Int64] = []

    init(response: Response) {
        self.response = response
        self.responsesByHost = [:]
    }

    init(responsesByHost: [String: Response], defaultResponse: Response = .success) {
        self.response = defaultResponse
        self.responsesByHost = responsesByHost
    }

    func sendFollow(_ request: ActivityPubFollowRequestDto) async throws {
        sentFollowIds.append(request.id)
        try self.resolveResponse(for: request.sharedInbox)
    }

    func sendMove(_ request: ActivityPubMoveRequestDto) async throws {
        sentMoveIds.append(request.id)
        try self.resolveResponse(for: request.sharedInbox)
    }

    func followIds() -> [Int64] {
        sentFollowIds
    }

    func moveIds() -> [Int64] {
        sentMoveIds
    }

    private func resolveResponse(for url: URL) throws {
        let selectedResponse = url.host.flatMap { responsesByHost[$0] } ?? response
        switch selectedResponse {
        case .success:
            return
        case .connectionError:
            throw URLError(.timedOut)
        case .httpStatus(let statusCode):
            guard let response = HTTPURLResponse(url: url,
                                                 statusCode: statusCode,
                                                 httpVersion: nil,
                                                 headerFields: nil) else {
                throw NetworkError.unknownError
            }
            throw NetworkError.notSuccessResponse(response, nil)
        }
    }
}
