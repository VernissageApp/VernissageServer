import Vapor

struct AuthClientDto {
    var id: UUID?
    var type: AuthClientType
    var name: String
    var uri: String
    var tenantId: String?
    var clientId: String
    var clientSecret: String
    var callbackUrl: String
    var svgIcon: String?
}

extension AuthClientDto {
    init(from authClient: AuthClient) {
        self.init(id: authClient.id,
                  type: authClient.type,
                  name: authClient.name,
                  uri: authClient.uri,
                  tenantId: authClient.tenantId,
                  clientId: authClient.clientId,
                  clientSecret: "",
                  callbackUrl: authClient.callbackUrl,
                  svgIcon: authClient.svgIcon)
    }
}

extension AuthClientDto: Content { }

extension AuthClientDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: .count(...50))
        validations.add("uri", as: String.self, is: .count(...300))
        validations.add("tenantId", as: String?.self, is: .count(...200) || .nil, required: false)
        validations.add("clientId", as: String.self, is: .count(...200))
        validations.add("clientSecret", as: String.self, is: .count(...200))
        validations.add("callbackUrl", as: String.self, is: .count(...300))
        validations.add("svgIcon", as: String?.self, is: .count(...8000) || .nil, required: false)
    }
}
