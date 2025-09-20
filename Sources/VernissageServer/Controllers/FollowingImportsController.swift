//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension FollowingImportsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("following-imports")
    
    func boot(routes: RoutesBuilder) throws {
        let relationshipsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(FollowingImportsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())

        relationshipsGroup
            .grouped(EventHandlerMiddleware(.followImportsList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
        
        relationshipsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.followImportsUpload))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: upload)
    }
}

/// Controller for managing user's follow imports.
///
/// Thanks to this controller user can upload file file user's account information
/// who should be automatically follow by the user.
///
/// > Important: Base controller URL: `/api/v1/following-imports`.
struct FollowingImportsController {
    
    private struct FileRequest: Content {
        var file: File
    }
    
    /// List of imports done by user.
    ///
    /// The endpoint returns a list of imports which has been run by user.
    /// The list supports paging using query parameters.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    ///
    /// > Important: Endpoint URL: `/api/v1/following-imports`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/following-imports" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of follow imports.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<FollowingImportDto> {
        let authorizationPayloadId = try request.requireUserId()
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
                        
        let followingImportsFromDatabase = try await FollowingImport.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .with(\.$followingImportItems)
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: size))
        
        let followingImportsDtos = followingImportsFromDatabase.items.map {
            FollowingImportDto(from: $0)
        }

        return PaginableResultDto(
            data: followingImportsDtos,
            page: followingImportsFromDatabase.metadata.page,
            size: followingImportsFromDatabase.metadata.per,
            total: followingImportsFromDatabase.metadata.total
        )
    }
    
    /// Uploading file with user's accounts to follow.
    ///
    /// The endpoint is used to manage the uploaded file with user's acounts to follow.
    ///
    /// > Important: Endpoint URL: `/api/v1/following-imports`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/following-imports" \
    /// -X POST \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -F 'file=@"/data/following.csv"'
    /// ```
    ///
    /// **Example request header:**
    ///
    /// ```
    /// Content-Type: multipart/form-data; boundary=----WebKitFormBoundaryozM7tKuqLq2psuEB
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```
    /// ------WebKitFormBoundaryozM7tKuqLq2psuEB
    /// Content-Disposition: form-data; name="file"; filename="following.csv"
    /// Content-Type: image/png
    ///
    /// ------WebKitFormBoundaryozM7tKuqLq2psuEB--
    /// [BINARY_DATA]
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7333518540363030529",
    ///     "status": "new",
    ///     "followingImportItems": [ ]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about following import.
    ///
    /// - Throws: `FollowImportError.missingFile` if missing file with accounts.
    /// - Throws: `FollowImportError.emptyFile` if file accounts is empty.
    /// - Throws: `EntityNotFoundError.archiveNotFound` if imported archive entity not exists.
    @Sendable
    func upload(request: Request) async throws -> FollowingImportDto {
        let authorizationPayloadId = try request.requireUserId()
        
        guard var fileRequest = try? request.content.decode(FileRequest.self) else {
            throw FollowImportError.missingFile
        }
        
        guard let fileDataString = fileRequest.file.data.readString(length: fileRequest.file.data.readableBytes, encoding: .utf8) else {
            throw FollowImportError.emptyFile
        }
        
        let newFollowingImportId = request.application.services.snowflakeService.generate()
        let followingImport = FollowingImport(id: newFollowingImportId, userId: authorizationPayloadId)
        var followingImportItems: [FollowingImportItem] = []
        
        // Parse file into lines and add following import items.
        let lines = fileDataString.split(separator: "\n")
        for line in lines {
            if line.uppercased().starts(with: "ACCOUNT ADDRESS") {
                continue
            }
            
            let lineParts = line.split(separator: ",")
            guard lineParts.count == 3 || lineParts.count == 4 else {
                continue
            }
            
            let languages: String? = if lineParts.count == 4 {
                String(lineParts[3])
            } else {
                nil
            }
            
            let newFollowingImportItemId = request.application.services.snowflakeService.generate()
            let followingImportItem = FollowingImportItem(id: newFollowingImportItemId,
                                                          followingImportId: newFollowingImportId,
                                                          account: String(lineParts[0]),
                                                          showBoosts: lineParts[1].uppercased() == "TRUE",
                                                          languages: languages)
            
            followingImportItems.append(followingImportItem)
        }
        
        // Saving new following import to database.
        let followingImportItemsToSave = followingImportItems
        try await request.db.transaction { database in
            try await followingImport.save(on: database)
            
            for followingImportItem in followingImportItemsToSave {
                try await followingImportItem.save(on: database)
            }
        }
        
        let followingImportsService = request.application.services.followingImportsService
        guard let followingImportFromDatabase = try await followingImportsService.get(by: newFollowingImportId, on: request.db) else {
            throw EntityNotFoundError.archiveNotFound
        }
        
        // Dispatch job for processing imported file.
        try await request
            .queues(.followingImporter)
            .dispatch(FollowingImporterJob.self, newFollowingImportId)

        return FollowingImportDto(from: followingImportFromDatabase)
    }
}
