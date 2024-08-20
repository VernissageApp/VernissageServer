//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct TwoFactorTokenDto {
    let key: String
    let label: String
    let issuer: String
    let url: String
    let backupCodes: [String]
    
    init(from twoFactorToken: TwoFactorToken, for user: User) {
        let issuer = "Vernissage"
        let url = "otpauth://totp/\(user.userName)?secret=\(twoFactorToken.key)&issuer=\(issuer)"
        
        self.backupCodes = twoFactorToken.backupTokens
        self.key = twoFactorToken.key
        self.label = user.userName
        self.issuer = issuer
        self.url = url
    }
}

extension TwoFactorTokenDto: Content { }
