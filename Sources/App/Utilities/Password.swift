import Vapor
import Crypto

public class Password {
    public static func generateSalt() -> String {
        let randomData = [UInt8].random(count: 16)
        let encodedSalt = randomData.base64
        return encodedSalt
    }

    public static func hash(_ password: String, withSalt salt: String) throws -> String {
        let salted = "\(salt)+\(password)"
        guard let slatedData = salted.data(using: .utf8) else {
            throw Abort(.internalServerError, reason: "Password cannot be encrypted.")
        }
        
        let passwordData = SHA256.hash(data: slatedData)
        return passwordData.hexEncodedString()
    }
}
