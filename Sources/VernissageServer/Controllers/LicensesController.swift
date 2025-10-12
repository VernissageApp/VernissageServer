//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension LicensesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("licenses")
    
    func boot(routes: RoutesBuilder) throws {
        let locationsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(LicensesController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        locationsGroup
            .grouped(EventHandlerMiddleware(.licensesList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
        
        locationsGroup
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.licensesCreate))
            .grouped(CacheControlMiddleware(.noStore))
            .post(use: create)

        locationsGroup
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.licensesUpdate))
            .grouped(CacheControlMiddleware(.noStore))
            .put(":id", use: update)
        
        locationsGroup
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.licensesDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":id", use: delete)
    }
}

/// Exposing list of supported licenses.
///
/// Each status can have a license assigned to it, so you know whether you
/// can further distribute the work and under what conditions.
///
/// > Important: Base controller URL: `/api/v1/licenses`.
struct LicensesController {
        
    /// Exposing list of licenses.
    ///
    /// An endpoint that returns a list of licenses added to the system.
    /// The license `id` is used when adding a new status to the system.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    ///
    /// > Important: Endpoint URL: `/api/v1/licenses`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/rules" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "data": [{
    ///         "code": "",
    ///         "description": "You, the copyright holder, ... waived under this license.",
    ///         "id": "7310961711425626113",
    ///         "name": "All Rights Reserved"
    ///     }, {
    ///         "code": "CC BY-NC-ND",
    ///         "description": "This license allows reusers ... is given to the creator.",
    ///         "id": "7310961711425757185",
    ///         "name": "Attribution-NonCommercial-NoDerivs",
    ///         "url": "https:\/\/creativecommons.org\/licenses\/by-nc-nd\/4.0\/"
    ///     }],
    ///     "page": 1,
    ///     "size": 2,
    ///     "total": 176
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of paginable licenses.
    @Sendable
    func list(request: Request) async throws -> PaginableResultDto<LicenseDto> {
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        
        let licensesFromDatabase = try await License.query(on: request.db)
            .sort(\.$name, .ascending)
            .paginate(PageRequest(page: page, per: size))
        
        let licensesDtos = licensesFromDatabase.items.map { license in
            LicenseDto(from: license)
        }

        return PaginableResultDto(
            data: licensesDtos,
            page: licensesFromDatabase.metadata.page,
            size: licensesFromDatabase.metadata.per,
            total: licensesFromDatabase.metadata.total
        )
    }
    
    /// Create new license.
    ///
    /// The endpoint can be used for creating new license.
    ///
    /// > Important: Endpoint URL: `/api/v1/licenses`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/licenses" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "code": "CC BY-NC-ND",
    ///     "description": "This license allows reusers ... is given to the creator.",
    ///     "name": "Attribution-NonCommercial-NoDerivs",
    ///     "url": "https:\/\/creativecommons.org\/licenses\/by-nc-nd\/4.0\/"
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7310961711425757185",
    ///     "code": "CC BY-NC-ND",
    ///     "description": "This license allows reusers ... is given to the creator.",
    ///     "name": "Attribution-NonCommercial-NoDerivs",
    ///     "url": "https:\/\/creativecommons.org\/licenses\/by-nc-nd\/4.0\/"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: New added entity.
    @Sendable
    func create(request: Request) async throws -> Response {
        let licenseDto = try request.content.decode(LicenseDto.self)
        try LicenseDto.validate(content: request)
        
        let id = request.application.services.snowflakeService.generate()
        let license = License(id: id, name: licenseDto.name, code: licenseDto.code, description: licenseDto.description, url: licenseDto.url)

        try await license.save(on: request.db)
        return try await createNewLicenseResponse(on: request, license: license)
    }
    
    /// Update license in the database.
    ///
    /// The endpoint can be used for updating existing license.
    ///
    /// > Important: Endpoint URL: `/api/v1/licenses/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/licenses/7310961711425757185" \
    /// -X PUT \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "id": "7310961711425757185",
    ///     "code": "CC BY-NC-ND (2025)",
    ///     "description": "This license allows reusers ... is given to the creator.",
    ///     "name": "Attribution-NonCommercial-NoDerivs",
    ///     "url": "https:\/\/creativecommons.org\/licenses\/by-nc-nd\/4.0\/"
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7310961711425757185",
    ///     "code": "CC BY-NC-ND (2025)",
    ///     "description": "This license allows reusers ... is given to the creator.",
    ///     "name": "Attribution-NonCommercial-NoDerivs",
    ///     "url": "https:\/\/creativecommons.org\/licenses\/by-nc-nd\/4.0\/"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Updated entity.
    ///
    /// - Throws: `LicenseError.incorrectLicenseId` if license id is incorrect.
    /// - Throws: `EntityNotFoundError.licenseNotFound` if rule not exists.
    @Sendable
    func update(request: Request) async throws -> LicenseDto {
        let licenseDto = try request.content.decode(LicenseDto.self)
        try LicenseDto.validate(content: request)
        
        guard let licenseIdString = request.parameters.get("id", as: String.self) else {
            throw LicenseError.incorrectLicenseId
        }
        
        guard let licenseId = licenseIdString.toId() else {
            throw LicenseError.incorrectLicenseId
        }
        
        guard let license = try await License.find(licenseId, on: request.db) else {
            throw EntityNotFoundError.licenseNotFound
        }
        
        license.name = licenseDto.name
        license.description = licenseDto.description
        license.code = licenseDto.code
        license.url = licenseDto.url

        try await license.save(on: request.db)
        return LicenseDto(from: license)
    }
    
    /// Delete license from the database.
    ///
    /// The endpoint can be used for deleting existing license.
    ///
    /// > Important: Endpoint URL: `/api/v1/licenses/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/licenses/7310961711425757185" \
    /// -X DELETE \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Http status code.
    ///
    /// - Throws: `LicenseError.incorrectLicenseId` if license id is incorrect.
    /// - Throws: `LicenseError.licenseAlreadyInUse` if license is already in use.
    /// - Throws: `EntityNotFoundError.licenseNotFound` if rule not exists.
    @Sendable
    func delete(request: Request) async throws -> HTTPStatus {
        guard let licenseIdString = request.parameters.get("id", as: String.self) else {
            throw LicenseError.incorrectLicenseId
        }
        
        guard let licenseId = licenseIdString.toId() else {
            throw LicenseError.incorrectLicenseId
        }
        
        guard let license = try await License.find(licenseId, on: request.db) else {
            throw EntityNotFoundError.licenseNotFound
        }
        
        let attachment = try await Attachment.query(on: request.db)
            .filter(\.$license.$id == licenseId)
            .first()
        
        guard attachment == nil else {
            throw LicenseError.licenseAlreadyInUse
        }
        
        let attachmentHistory = try await AttachmentHistory.query(on: request.db)
            .filter(\.$license.$id == licenseId)
            .first()
        
        guard attachmentHistory == nil else {
            throw LicenseError.licenseAlreadyInUse
        }
        
        try await license.delete(on: request.db)
        return HTTPStatus.ok
    }
    
    private func createNewLicenseResponse(on request: Request, license: License) async throws -> Response {
        let licenseDto = LicenseDto(from: license)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .location, value: "/\(LicensesController.uri)/\(license.stringId() ?? "")")
        
        return try await licenseDto.encodeResponse(status: .created, headers: headers, for: request)
    }
}
