import Vapor

struct UserDto {
    var id: UUID?
    var userName: String
    var email: String?
    var name: String?
    var bio: String?
    var location: String?
    var website: String?
    var birthDate: Date?
    var gravatarHash: String?
}

extension UserDto {
    init(from user: User) {
        self.init(
            id: user.id,
            userName: user.userName,
            email: user.email,
            name: user.name,
            bio: user.bio,
            location: user.location,
            website: user.website,
            birthDate: user.birthDate,
            gravatarHash: user.gravatarHash
        )
    }
}

extension UserDto: Content { }

extension UserDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String?.self, is: .count(...50) || .nil, required: false)
        validations.add("location", as: String?.self, is: .count(...50) || .nil, required: false)
        validations.add("website", as: String?.self, is: .count(...50) || .nil, required: false)
        validations.add("bio", as: String?.self, is: .count(...200) || .nil, required: false)
    }
}
