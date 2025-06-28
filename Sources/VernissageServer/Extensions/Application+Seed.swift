//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application {

    func seedDictionaries() async throws {
        let database = self.db
        try await settings(on: database)
        try await roles(on: database)
        try await localizables(on: database)
        try await countries(on: database)
        try await categories(on: database)
        try await licenses(on: database)
        try await disposableEmails(on: database)
    }
    
    func seedAdmin() async throws {
        let database = self.db
        try await users(on: database)
        try await setSystemDefaultUser(on: database)
    }

    private func settings(on database: Database) async throws {
        let settings = try await Setting.query(on: database).all()

        // General.
        try await ensureSettingExists(on: database, existing: settings, key: .webTitle, value: .string("Vernissage"))
        try await ensureSettingExists(on: database, existing: settings, key: .webDescription, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .webLongDescription, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .webEmail, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .webThumbnail, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .webLanguages, value: .string("en"))
        try await ensureSettingExists(on: database, existing: settings, key: .webContactUserId, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .isRegistrationOpened, value: .boolean(true))
        try await ensureSettingExists(on: database, existing: settings, key: .isRegistrationByApprovalOpened, value: .boolean(false))
        try await ensureSettingExists(on: database, existing: settings, key: .isRegistrationByInvitationsOpened, value: .boolean(false))
        try await ensureSettingExists(on: database, existing: settings, key: .corsOrigin, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .maximumNumberOfInvitations, value: .int(10))
        try await ensureSettingExists(on: database, existing: settings, key: .maxCharacters, value: .int(Constants.statusMaxCharacters))
        try await ensureSettingExists(on: database, existing: settings, key: .maxMediaAttachments, value: .int(Constants.statusMaxMediaAttachments))
        try await ensureSettingExists(on: database, existing: settings, key: .imageSizeLimit, value: .int(Constants.imageSizeLimit))
        try await ensureSettingExists(on: database, existing: settings, key: .systemDefaultUserId, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .patreonUrl, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .mastodonUrl, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .statusPurgeAfterDays, value: .int(180))
        try await ensureSettingExists(on: database, existing: settings, key: .imagesUrl, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .showNews, value: .boolean(false))
        try await ensureSettingExists(on: database, existing: settings, key: .showNewsForAnonymous, value: .boolean(false))
        try await ensureSettingExists(on: database, existing: settings, key: .showSharedBusinessCards, value: .boolean(false))
        try await ensureSettingExists(on: database, existing: settings, key: .imageQuality, value: .int(Constants.imageQuality))

        // Financial support.
        try await ensureSettingExists(on: database, existing: settings, key: .totalCost, value: .int(0))
        try await ensureSettingExists(on: database, existing: settings, key: .usersSupport, value: .int(0))
        
        // Recaptcha (unsupported: enum will be deleted in next versions).
        try await deleteSetting(on: database, key: .isRecaptchaEnabled)
        try await deleteSetting(on: database, key: .recaptchaKey)
        
        // Quick captcha.
        try await ensureSettingExists(on: database, existing: settings, key: .isQuickCaptchaEnabled, value: .boolean(false))

        // Events.
        try await ensureSettingExists(on: database,
                                      existing: settings,
                                      key: .eventsToStore,
                                      value: .string(EventType.allCases.map { item -> String in item.rawValue }.joined(separator: ",")))

        // JWT keys.
        let (privateKey, publicKey) = try CryptoService().generateKeys()
        try await ensureSettingExists(on: database, existing: settings, key: .jwtPrivateKey, value: .string(privateKey))
        try await ensureSettingExists(on: database, existing: settings, key: .jwtPublicKey, value: .string(publicKey))
        
        // Email server.
        try await ensureSettingExists(on: database, existing: settings, key: .emailHostname, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .emailPort, value: .int(465))
        try await ensureSettingExists(on: database, existing: settings, key: .emailUserName, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .emailPassword, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .emailSecureMethod, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .emailFromAddress, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .emailFromName, value: .string(""))
        
        // OpenAI.
        try await ensureSettingExists(on: database, existing: settings, key: .isOpenAIEnabled, value: .boolean(false))
        try await ensureSettingExists(on: database, existing: settings, key: .openAIKey, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .openAIModel, value: .string("gpt-4-turbo"))
        
        // WebPush.
        try await ensureSettingExists(on: database, existing: settings, key: .isWebPushEnabled, value: .boolean(false))
        try await ensureSettingExists(on: database, existing: settings, key: .webPushEndpoint, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .webPushSecretKey, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .webPushVapidPublicKey, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .webPushVapidPrivateKey, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .webPushVapidSubject, value: .string(""))
        
        // Visible pages for anonymous.
        try await ensureSettingExists(on: database, existing: settings, key: .showLocalTimelineForAnonymous, value: .boolean(true))
        try await ensureSettingExists(on: database, existing: settings, key: .showTrendingForAnonymous, value: .boolean(false))
        try await ensureSettingExists(on: database, existing: settings, key: .showEditorsChoiceForAnonymous, value: .boolean(false))
        try await ensureSettingExists(on: database, existing: settings, key: .showEditorsUsersChoiceForAnonymous, value: .boolean(false))
        try await ensureSettingExists(on: database, existing: settings, key: .showHashtagsForAnonymous, value: .boolean(false))
        try await ensureSettingExists(on: database, existing: settings, key: .showCategoriesForAnonymous, value: .boolean(false))
        
        // Privacy and Terms of Service.
        try await ensureSettingExists(on: database, existing: settings, key: .privacyPolicyUpdatedAt, value: .string("2025-01-18"))
        try await ensureSettingExists(on: database, existing: settings, key: .privacyPolicyContent, value: .string(Constants.defaultPrivacyPolicy))
        try await ensureSettingExists(on: database, existing: settings, key: .termsOfServiceUpdatedAt, value: .string("2025-01-18"))
        try await ensureSettingExists(on: database, existing: settings, key: .termsOfServiceContent, value: .string(Constants.defaultTermsOfService))
        
        // Custom style and script.
        try await ensureSettingExists(on: database, existing: settings, key: .customInlineScript, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .customInlineStyle, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .customFileScript, value: .string(""))
        try await ensureSettingExists(on: database, existing: settings, key: .customFileStyle, value: .string(""))
    }

    private func roles(on database: Database) async throws {
        let roles = try await Role.query(on: database).all()

        try await ensureRoleExists(on: database,
                                   existing: roles,
                                   code: Role.administrator,
                                   title: "Administrator",
                                   description: "Users have access to whole system.",
                                   isDefault: false)

        try await ensureRoleExists(on: database,
                                   existing: roles,
                                   code: Role.moderator,
                                   title: "Moderator",
                                   description: "Users have access to content moderation (approve users/block users etc.).",
                                   isDefault: false)
        
        try await ensureRoleExists(on: database,
                                   existing: roles,
                                   code: Role.member,
                                   title: "Member",
                                   description: "Users have access to public part of system.",
                                   isDefault: true)
    }
    
    private func users(on database: Database) async throws {
        try await ensureAdminExist(on: database)
    }
    
    private func setSystemDefaultUser(on database: Database) async throws {
        guard let systemDefaultUserIdSetting = try await Setting.query(on: database)
            .filter(\.$key == SettingKey.systemDefaultUserId.rawValue)
            .first() else {
            return
        }
        
        if systemDefaultUserIdSetting.value != "" {
            return
        }
        
        guard let systemUser = try await User.query(on: database).filter(\.$userName == "admin").first() else {
            return
        }
        
        systemDefaultUserIdSetting.value = systemUser.stringId() ?? ""
        try await systemDefaultUserIdSetting.save(on: database)
    }
    
    private func licenses(on database: Database) async throws {
        let licenses = try await License.query(on: database).all()
        
        try await ensureLicenseExists(
            on: database,
            existing: licenses,
            code: "",
            name: "All Rights Reserved",
            description: "You, the copyright holder, reserve all rights provided by copyright law, such as the right to make copies, distribute your work, perform your work, license, or otherwise exploit your work; no rights are waived under this license.",
            url: nil
        );
        
        try await ensureLicenseExists(
            on: database,
            existing: licenses,
            code: "",
            name: "Public Domain",
            description: "Works, or aspects of copyrighted works, which copyright law does not protect.",
            url: nil
        );
        
        try await ensureLicenseExists(
            on: database,
            existing: licenses,
            code: "CC0",
            name: "Public Domain",
            description: "You, the copyright holder, waive your interest in your work and place the work as completely as possible in the public domain so others may freely exploit and use the work without restriction under copyright or database law.",
            url: nil
        );
        
        try await ensureLicenseExists(
            on: database,
            existing: licenses,
            code: "CC BY",
            name: "Attribution",
            description: "This license allows reusers to distribute, remix, adapt, and build upon the material in any medium or format, so long as attribution is given to the creator. The license allows for commercial use.",
            url: "https://creativecommons.org/licenses/by/4.0/"
        );
        
        try await ensureLicenseExists(
            on: database,
            existing: licenses,
            code: "CC BY-SA",
            name: "Attribution-ShareAlike",
            description: "This license allows reusers to distribute, remix, adapt, and build upon the material in any medium or format, so long as attribution is given to the creator. The license allows for commercial use. If you remix, adapt, or build upon the material, you must license the modified material under identical terms.",
            url: "https://creativecommons.org/licenses/by-sa/4.0/"
        );
        
        try await ensureLicenseExists(
            on: database,
            existing: licenses,
            code: "CC BY-NC",
            name: "Attribution-NonCommercial",
            description: "This license allows reusers to distribute, remix, adapt, and build upon the material in any medium or format for noncommercial purposes only, and only so long as attribution is given to the creator.",
            url: "https://creativecommons.org/licenses/by-nc/4.0/"
        );
        
        try await ensureLicenseExists(
            on: database,
            existing: licenses,
            code: "CC BY-NC-SA",
            name: "Attribution-NonCommercial-ShareAlike",
            description: "This license allows reusers to distribute, remix, adapt, and build upon the material in any medium or format for noncommercial purposes only, and only so long as attribution is given to the creator. If you remix, adapt, or build upon the material, you must license the modified material under identical terms.",
            url: "https://creativecommons.org/licenses/by-nc-sa/4.0/"
        );
        
        try await ensureLicenseExists(
            on: database,
            existing: licenses,
            code: "CC BY-ND",
            name: "Attribution-NoDerivs",
            description: "This license allows reusers to copy and distribute the material in any medium or format in unadapted form only, and only so long as attribution is given to the creator. The license allows for commercial use.",
            url: "https://creativecommons.org/licenses/by-nd/4.0/"
        );
        
        try await ensureLicenseExists(
            on: database,
            existing: licenses,
            code: "CC BY-NC-ND",
            name: "Attribution-NonCommercial-NoDerivs",
            description: "This license allows reusers to copy and distribute the material in any medium or format in unadapted form only, for noncommercial purposes only, and only so long as attribution is given to the creator.",
            url: "https://creativecommons.org/licenses/by-nc-nd/4.0/"
        );
    }
    
    private func countries(on database: Database) async throws {
        let countries = try await Country.query(on: database).all()
        
        try await ensureCountryExists(on: database, existing: countries, code: "AF", name: "Afghanistan");
        try await ensureCountryExists(on: database, existing: countries, code: "AL", name: "Albania");
        try await ensureCountryExists(on: database, existing: countries, code: "DZ", name: "Algeria");
        try await ensureCountryExists(on: database, existing: countries, code: "AS", name: "American Samoa");
        try await ensureCountryExists(on: database, existing: countries, code: "AD", name: "Andorra");
        try await ensureCountryExists(on: database, existing: countries, code: "AO", name: "Angola");
        try await ensureCountryExists(on: database, existing: countries, code: "AI", name: "Anguilla");
        try await ensureCountryExists(on: database, existing: countries, code: "AQ", name: "Antarctica");
        try await ensureCountryExists(on: database, existing: countries, code: "AG", name: "Antigua and Barbuda");
        try await ensureCountryExists(on: database, existing: countries, code: "AR", name: "Argentina");
        try await ensureCountryExists(on: database, existing: countries, code: "AM", name: "Armenia");
        try await ensureCountryExists(on: database, existing: countries, code: "AW", name: "Aruba");
        try await ensureCountryExists(on: database, existing: countries, code: "AU", name: "Australia");
        try await ensureCountryExists(on: database, existing: countries, code: "AT", name: "Austria");
        try await ensureCountryExists(on: database, existing: countries, code: "AZ", name: "Azerbaijan");
        try await ensureCountryExists(on: database, existing: countries, code: "BS", name: "Bahamas");
        try await ensureCountryExists(on: database, existing: countries, code: "BH", name: "Bahrain");
        try await ensureCountryExists(on: database, existing: countries, code: "BD", name: "Bangladesh");
        try await ensureCountryExists(on: database, existing: countries, code: "BB", name: "Barbados");
        try await ensureCountryExists(on: database, existing: countries, code: "BY", name: "Belarus");
        try await ensureCountryExists(on: database, existing: countries, code: "BE", name: "Belgium");
        try await ensureCountryExists(on: database, existing: countries, code: "BZ", name: "Belize");
        try await ensureCountryExists(on: database, existing: countries, code: "BJ", name: "Benin");
        try await ensureCountryExists(on: database, existing: countries, code: "BM", name: "Bermuda");
        try await ensureCountryExists(on: database, existing: countries, code: "BT", name: "Bhutan");
        try await ensureCountryExists(on: database, existing: countries, code: "BO", name: "Bolivia");
        try await ensureCountryExists(on: database, existing: countries, code: "BQ", name: "Bonaire, Sint Eustatius and Saba");
        try await ensureCountryExists(on: database, existing: countries, code: "BA", name: "Bosnia and Herzegovina");
        try await ensureCountryExists(on: database, existing: countries, code: "BW", name: "Botswana");
        try await ensureCountryExists(on: database, existing: countries, code: "BV", name: "Bouvet Island");
        try await ensureCountryExists(on: database, existing: countries, code: "BR", name: "Brazil");
        try await ensureCountryExists(on: database, existing: countries, code: "IO", name: "British Indian Ocean Territory");
        try await ensureCountryExists(on: database, existing: countries, code: "BN", name: "Brunei Darussalam");
        try await ensureCountryExists(on: database, existing: countries, code: "BG", name: "Bulgaria");
        try await ensureCountryExists(on: database, existing: countries, code: "BF", name: "Burkina Faso");
        try await ensureCountryExists(on: database, existing: countries, code: "BI", name: "Burundi");
        try await ensureCountryExists(on: database, existing: countries, code: "CV", name: "Cabo Verde");
        try await ensureCountryExists(on: database, existing: countries, code: "KH", name: "Cambodia");
        try await ensureCountryExists(on: database, existing: countries, code: "CM", name: "Cameroon");
        try await ensureCountryExists(on: database, existing: countries, code: "CA", name: "Canada");
        try await ensureCountryExists(on: database, existing: countries, code: "KY", name: "Cayman Islands");
        try await ensureCountryExists(on: database, existing: countries, code: "CF", name: "Central African Republic");
        try await ensureCountryExists(on: database, existing: countries, code: "TD", name: "Chad");
        try await ensureCountryExists(on: database, existing: countries, code: "CL", name: "Chile");
        try await ensureCountryExists(on: database, existing: countries, code: "CN", name: "China");
        try await ensureCountryExists(on: database, existing: countries, code: "CX", name: "Christmas Island");
        try await ensureCountryExists(on: database, existing: countries, code: "CC", name: "Cocos (Keeling) Islands");
        try await ensureCountryExists(on: database, existing: countries, code: "CO", name: "Colombia");
        try await ensureCountryExists(on: database, existing: countries, code: "KM", name: "Comoros");
        try await ensureCountryExists(on: database, existing: countries, code: "CD", name: "Democratic Republic of the Congo");
        try await ensureCountryExists(on: database, existing: countries, code: "CG", name: "Congo");
        try await ensureCountryExists(on: database, existing: countries, code: "CK", name: "Cook Islands");
        try await ensureCountryExists(on: database, existing: countries, code: "CR", name: "Costa Rica");
        try await ensureCountryExists(on: database, existing: countries, code: "HR", name: "Croatia");
        try await ensureCountryExists(on: database, existing: countries, code: "CU", name: "Cuba");
        try await ensureCountryExists(on: database, existing: countries, code: "CW", name: "Curaçao");
        try await ensureCountryExists(on: database, existing: countries, code: "CY", name: "Cyprus");
        try await ensureCountryExists(on: database, existing: countries, code: "CZ", name: "Czechia");
        try await ensureCountryExists(on: database, existing: countries, code: "CI", name: "Côte d'Ivoire");
        try await ensureCountryExists(on: database, existing: countries, code: "DK", name: "Denmark");
        try await ensureCountryExists(on: database, existing: countries, code: "DJ", name: "Djibouti");
        try await ensureCountryExists(on: database, existing: countries, code: "DM", name: "Dominica");
        try await ensureCountryExists(on: database, existing: countries, code: "DO", name: "Dominican Republic");
        try await ensureCountryExists(on: database, existing: countries, code: "EC", name: "Ecuador");
        try await ensureCountryExists(on: database, existing: countries, code: "EG", name: "Egypt");
        try await ensureCountryExists(on: database, existing: countries, code: "SV", name: "El Salvador");
        try await ensureCountryExists(on: database, existing: countries, code: "GQ", name: "Equatorial Guinea");
        try await ensureCountryExists(on: database, existing: countries, code: "ER", name: "Eritrea");
        try await ensureCountryExists(on: database, existing: countries, code: "EE", name: "Estonia");
        try await ensureCountryExists(on: database, existing: countries, code: "SZ", name: "Eswatini");
        try await ensureCountryExists(on: database, existing: countries, code: "ET", name: "Ethiopia");
        try await ensureCountryExists(on: database, existing: countries, code: "FK", name: "Falkland Islands [Malvinas]");
        try await ensureCountryExists(on: database, existing: countries, code: "FO", name: "Faroe Islands");
        try await ensureCountryExists(on: database, existing: countries, code: "FJ", name: "Fiji");
        try await ensureCountryExists(on: database, existing: countries, code: "FI", name: "Finland");
        try await ensureCountryExists(on: database, existing: countries, code: "FR", name: "France");
        try await ensureCountryExists(on: database, existing: countries, code: "GF", name: "French Guiana");
        try await ensureCountryExists(on: database, existing: countries, code: "PF", name: "French Polynesia");
        try await ensureCountryExists(on: database, existing: countries, code: "TF", name: "French Southern Territories");
        try await ensureCountryExists(on: database, existing: countries, code: "GA", name: "Gabon");
        try await ensureCountryExists(on: database, existing: countries, code: "GM", name: "Gambia");
        try await ensureCountryExists(on: database, existing: countries, code: "GE", name: "Georgia");
        try await ensureCountryExists(on: database, existing: countries, code: "DE", name: "Germany");
        try await ensureCountryExists(on: database, existing: countries, code: "GH", name: "Ghana");
        try await ensureCountryExists(on: database, existing: countries, code: "GI", name: "Gibraltar");
        try await ensureCountryExists(on: database, existing: countries, code: "GR", name: "Greece");
        try await ensureCountryExists(on: database, existing: countries, code: "GL", name: "Greenland");
        try await ensureCountryExists(on: database, existing: countries, code: "GD", name: "Grenada");
        try await ensureCountryExists(on: database, existing: countries, code: "GP", name: "Guadeloupe");
        try await ensureCountryExists(on: database, existing: countries, code: "GU", name: "Guam");
        try await ensureCountryExists(on: database, existing: countries, code: "GT", name: "Guatemala");
        try await ensureCountryExists(on: database, existing: countries, code: "GG", name: "Guernsey");
        try await ensureCountryExists(on: database, existing: countries, code: "GN", name: "Guinea");
        try await ensureCountryExists(on: database, existing: countries, code: "GW", name: "Guinea-Bissau");
        try await ensureCountryExists(on: database, existing: countries, code: "GY", name: "Guyana");
        try await ensureCountryExists(on: database, existing: countries, code: "HT", name: "Haiti");
        try await ensureCountryExists(on: database, existing: countries, code: "HM", name: "Heard Island and McDonald Islands");
        try await ensureCountryExists(on: database, existing: countries, code: "VA", name: "Holy See");
        try await ensureCountryExists(on: database, existing: countries, code: "HN", name: "Honduras");
        try await ensureCountryExists(on: database, existing: countries, code: "HK", name: "Hong Kong");
        try await ensureCountryExists(on: database, existing: countries, code: "HU", name: "Hungary");
        try await ensureCountryExists(on: database, existing: countries, code: "IS", name: "Iceland");
        try await ensureCountryExists(on: database, existing: countries, code: "IN", name: "India");
        try await ensureCountryExists(on: database, existing: countries, code: "ID", name: "Indonesia");
        try await ensureCountryExists(on: database, existing: countries, code: "IR", name: "Iran");
        try await ensureCountryExists(on: database, existing: countries, code: "IQ", name: "Iraq");
        try await ensureCountryExists(on: database, existing: countries, code: "IE", name: "Ireland");
        try await ensureCountryExists(on: database, existing: countries, code: "IM", name: "Isle of Man");
        try await ensureCountryExists(on: database, existing: countries, code: "IL", name: "Israel");
        try await ensureCountryExists(on: database, existing: countries, code: "IT", name: "Italy");
        try await ensureCountryExists(on: database, existing: countries, code: "JM", name: "Jamaica");
        try await ensureCountryExists(on: database, existing: countries, code: "JP", name: "Japan");
        try await ensureCountryExists(on: database, existing: countries, code: "JE", name: "Jersey");
        try await ensureCountryExists(on: database, existing: countries, code: "JO", name: "Jordan");
        try await ensureCountryExists(on: database, existing: countries, code: "KZ", name: "Kazakhstan");
        try await ensureCountryExists(on: database, existing: countries, code: "KE", name: "Kenya");
        try await ensureCountryExists(on: database, existing: countries, code: "KI", name: "Kiribati");
        try await ensureCountryExists(on: database, existing: countries, code: "KP", name: "Democratic People's Republic of Korea");
        try await ensureCountryExists(on: database, existing: countries, code: "KR", name: "Republic of Korea");
        try await ensureCountryExists(on: database, existing: countries, code: "KW", name: "Kuwait");
        try await ensureCountryExists(on: database, existing: countries, code: "KG", name: "Kyrgyzstan");
        try await ensureCountryExists(on: database, existing: countries, code: "LA", name: "Lao People's Democratic Republic");
        try await ensureCountryExists(on: database, existing: countries, code: "LV", name: "Latvia");
        try await ensureCountryExists(on: database, existing: countries, code: "LB", name: "Lebanon");
        try await ensureCountryExists(on: database, existing: countries, code: "LS", name: "Lesotho");
        try await ensureCountryExists(on: database, existing: countries, code: "LR", name: "Liberia");
        try await ensureCountryExists(on: database, existing: countries, code: "LY", name: "Libya");
        try await ensureCountryExists(on: database, existing: countries, code: "LI", name: "Liechtenstein");
        try await ensureCountryExists(on: database, existing: countries, code: "LT", name: "Lithuania");
        try await ensureCountryExists(on: database, existing: countries, code: "LU", name: "Luxembourg");
        try await ensureCountryExists(on: database, existing: countries, code: "MO", name: "Macao");
        try await ensureCountryExists(on: database, existing: countries, code: "MG", name: "Madagascar");
        try await ensureCountryExists(on: database, existing: countries, code: "MW", name: "Malawi");
        try await ensureCountryExists(on: database, existing: countries, code: "MY", name: "Malaysia");
        try await ensureCountryExists(on: database, existing: countries, code: "MV", name: "Maldives");
        try await ensureCountryExists(on: database, existing: countries, code: "ML", name: "Mali");
        try await ensureCountryExists(on: database, existing: countries, code: "MT", name: "Malta");
        try await ensureCountryExists(on: database, existing: countries, code: "MH", name: "Marshall Islands");
        try await ensureCountryExists(on: database, existing: countries, code: "MQ", name: "Martinique");
        try await ensureCountryExists(on: database, existing: countries, code: "MR", name: "Mauritania");
        try await ensureCountryExists(on: database, existing: countries, code: "MU", name: "Mauritius");
        try await ensureCountryExists(on: database, existing: countries, code: "YT", name: "Mayotte");
        try await ensureCountryExists(on: database, existing: countries, code: "MX", name: "Mexico");
        try await ensureCountryExists(on: database, existing: countries, code: "FM", name: "Micronesia");
        try await ensureCountryExists(on: database, existing: countries, code: "MD", name: "Moldova");
        try await ensureCountryExists(on: database, existing: countries, code: "MC", name: "Monaco");
        try await ensureCountryExists(on: database, existing: countries, code: "MN", name: "Mongolia");
        try await ensureCountryExists(on: database, existing: countries, code: "ME", name: "Montenegro");
        try await ensureCountryExists(on: database, existing: countries, code: "MS", name: "Montserrat");
        try await ensureCountryExists(on: database, existing: countries, code: "MA", name: "Morocco");
        try await ensureCountryExists(on: database, existing: countries, code: "MZ", name: "Mozambique");
        try await ensureCountryExists(on: database, existing: countries, code: "MM", name: "Myanmar");
        try await ensureCountryExists(on: database, existing: countries, code: "NA", name: "Namibia");
        try await ensureCountryExists(on: database, existing: countries, code: "NR", name: "Nauru");
        try await ensureCountryExists(on: database, existing: countries, code: "NP", name: "Nepal");
        try await ensureCountryExists(on: database, existing: countries, code: "NL", name: "Netherlands");
        try await ensureCountryExists(on: database, existing: countries, code: "NC", name: "New Caledonia");
        try await ensureCountryExists(on: database, existing: countries, code: "NZ", name: "New Zealand");
        try await ensureCountryExists(on: database, existing: countries, code: "NI", name: "Nicaragua");
        try await ensureCountryExists(on: database, existing: countries, code: "NE", name: "Niger");
        try await ensureCountryExists(on: database, existing: countries, code: "NG", name: "Nigeria");
        try await ensureCountryExists(on: database, existing: countries, code: "NU", name: "Niue");
        try await ensureCountryExists(on: database, existing: countries, code: "NF", name: "Norfolk Island");
        try await ensureCountryExists(on: database, existing: countries, code: "MP", name: "Northern Mariana Islands");
        try await ensureCountryExists(on: database, existing: countries, code: "NO", name: "Norway");
        try await ensureCountryExists(on: database, existing: countries, code: "OM", name: "Oman");
        try await ensureCountryExists(on: database, existing: countries, code: "PK", name: "Pakistan");
        try await ensureCountryExists(on: database, existing: countries, code: "PW", name: "Palau");
        try await ensureCountryExists(on: database, existing: countries, code: "PS", name: "Palestine");
        try await ensureCountryExists(on: database, existing: countries, code: "PA", name: "Panama");
        try await ensureCountryExists(on: database, existing: countries, code: "PG", name: "Papua New Guinea");
        try await ensureCountryExists(on: database, existing: countries, code: "PY", name: "Paraguay");
        try await ensureCountryExists(on: database, existing: countries, code: "PE", name: "Peru");
        try await ensureCountryExists(on: database, existing: countries, code: "PH", name: "Philippines");
        try await ensureCountryExists(on: database, existing: countries, code: "PN", name: "Pitcairn");
        try await ensureCountryExists(on: database, existing: countries, code: "PL", name: "Poland");
        try await ensureCountryExists(on: database, existing: countries, code: "PT", name: "Portugal");
        try await ensureCountryExists(on: database, existing: countries, code: "PR", name: "Puerto Rico");
        try await ensureCountryExists(on: database, existing: countries, code: "QA", name: "Qatar");
        try await ensureCountryExists(on: database, existing: countries, code: "MK", name: "Republic of North Macedonia");
        try await ensureCountryExists(on: database, existing: countries, code: "RO", name: "Romania");
        try await ensureCountryExists(on: database, existing: countries, code: "RU", name: "Russian Federation");
        try await ensureCountryExists(on: database, existing: countries, code: "RW", name: "Rwanda");
        try await ensureCountryExists(on: database, existing: countries, code: "RE", name: "Réunion");
        try await ensureCountryExists(on: database, existing: countries, code: "BL", name: "Saint Barthélemy");
        try await ensureCountryExists(on: database, existing: countries, code: "SH", name: "Saint Helena, Ascension and Tristan da Cunha");
        try await ensureCountryExists(on: database, existing: countries, code: "KN", name: "Saint Kitts and Nevis");
        try await ensureCountryExists(on: database, existing: countries, code: "LC", name: "Saint Lucia");
        try await ensureCountryExists(on: database, existing: countries, code: "MF", name: "Saint Martin (French part)");
        try await ensureCountryExists(on: database, existing: countries, code: "PM", name: "Saint Pierre and Miquelon");
        try await ensureCountryExists(on: database, existing: countries, code: "VC", name: "Saint Vincent and the Grenadines");
        try await ensureCountryExists(on: database, existing: countries, code: "WS", name: "Samoa");
        try await ensureCountryExists(on: database, existing: countries, code: "SM", name: "San Marino");
        try await ensureCountryExists(on: database, existing: countries, code: "ST", name: "Sao Tome and Principe");
        try await ensureCountryExists(on: database, existing: countries, code: "SA", name: "Saudi Arabia");
        try await ensureCountryExists(on: database, existing: countries, code: "SN", name: "Senegal");
        try await ensureCountryExists(on: database, existing: countries, code: "RS", name: "Serbia");
        try await ensureCountryExists(on: database, existing: countries, code: "SC", name: "Seychelles");
        try await ensureCountryExists(on: database, existing: countries, code: "SL", name: "Sierra Leone");
        try await ensureCountryExists(on: database, existing: countries, code: "SG", name: "Singapore");
        try await ensureCountryExists(on: database, existing: countries, code: "SX", name: "Sint Maarten (Dutch part)");
        try await ensureCountryExists(on: database, existing: countries, code: "SK", name: "Slovakia");
        try await ensureCountryExists(on: database, existing: countries, code: "SI", name: "Slovenia");
        try await ensureCountryExists(on: database, existing: countries, code: "SB", name: "Solomon Islands");
        try await ensureCountryExists(on: database, existing: countries, code: "SO", name: "Somalia");
        try await ensureCountryExists(on: database, existing: countries, code: "ZA", name: "South Africa");
        try await ensureCountryExists(on: database, existing: countries, code: "GS", name: "South Georgia and the South Sandwich Islands");
        try await ensureCountryExists(on: database, existing: countries, code: "SS", name: "South Sudan");
        try await ensureCountryExists(on: database, existing: countries, code: "ES", name: "Spain");
        try await ensureCountryExists(on: database, existing: countries, code: "LK", name: "Sri Lanka");
        try await ensureCountryExists(on: database, existing: countries, code: "SD", name: "Sudan");
        try await ensureCountryExists(on: database, existing: countries, code: "SR", name: "Suriname");
        try await ensureCountryExists(on: database, existing: countries, code: "SJ", name: "Svalbard and Jan Mayen");
        try await ensureCountryExists(on: database, existing: countries, code: "SE", name: "Sweden");
        try await ensureCountryExists(on: database, existing: countries, code: "CH", name: "Switzerland");
        try await ensureCountryExists(on: database, existing: countries, code: "SY", name: "Syrian Arab Republic");
        try await ensureCountryExists(on: database, existing: countries, code: "TW", name: "Taiwan");
        try await ensureCountryExists(on: database, existing: countries, code: "TJ", name: "Tajikistan");
        try await ensureCountryExists(on: database, existing: countries, code: "TZ", name: "Tanzania");
        try await ensureCountryExists(on: database, existing: countries, code: "TH", name: "Thailand");
        try await ensureCountryExists(on: database, existing: countries, code: "TL", name: "Timor-Leste");
        try await ensureCountryExists(on: database, existing: countries, code: "TG", name: "Togo");
        try await ensureCountryExists(on: database, existing: countries, code: "TK", name: "Tokelau");
        try await ensureCountryExists(on: database, existing: countries, code: "TO", name: "Tonga");
        try await ensureCountryExists(on: database, existing: countries, code: "TT", name: "Trinidad and Tobago");
        try await ensureCountryExists(on: database, existing: countries, code: "TN", name: "Tunisia");
        try await ensureCountryExists(on: database, existing: countries, code: "TR", name: "Turkey");
        try await ensureCountryExists(on: database, existing: countries, code: "TM", name: "Turkmenistan");
        try await ensureCountryExists(on: database, existing: countries, code: "TC", name: "Turks and Caicos Islands");
        try await ensureCountryExists(on: database, existing: countries, code: "TV", name: "Tuvalu");
        try await ensureCountryExists(on: database, existing: countries, code: "UG", name: "Uganda");
        try await ensureCountryExists(on: database, existing: countries, code: "UA", name: "Ukraine");
        try await ensureCountryExists(on: database, existing: countries, code: "AE", name: "United Arab Emirates");
        try await ensureCountryExists(on: database, existing: countries, code: "GB", name: "United Kingdom of Great Britain and Northern Ireland");
        try await ensureCountryExists(on: database, existing: countries, code: "UM", name: "United States Minor Outlying Islands");
        try await ensureCountryExists(on: database, existing: countries, code: "US", name: "United States of America");
        try await ensureCountryExists(on: database, existing: countries, code: "UY", name: "Uruguay");
        try await ensureCountryExists(on: database, existing: countries, code: "UZ", name: "Uzbekistan");
        try await ensureCountryExists(on: database, existing: countries, code: "VU", name: "Vanuatu");
        try await ensureCountryExists(on: database, existing: countries, code: "VE", name: "Venezuela");
        try await ensureCountryExists(on: database, existing: countries, code: "VN", name: "Viet Nam");
        try await ensureCountryExists(on: database, existing: countries, code: "VG", name: "Virgin Islands (British)");
        try await ensureCountryExists(on: database, existing: countries, code: "VI", name: "Virgin Islands (U.S.)");
        try await ensureCountryExists(on: database, existing: countries, code: "WF", name: "Wallis and Futuna");
        try await ensureCountryExists(on: database, existing: countries, code: "EH", name: "Western Sahara");
        try await ensureCountryExists(on: database, existing: countries, code: "YE", name: "Yemen");
        try await ensureCountryExists(on: database, existing: countries, code: "ZM", name: "Zambia");
        try await ensureCountryExists(on: database, existing: countries, code: "ZW", name: "Zimbabwe");
        try await ensureCountryExists(on: database, existing: countries, code: "AX", name: "Åland Islands");
        try await ensureCountryExists(on: database, existing: countries, code: "XK", name: "Kosovo");
    }
    
    private func categories(on database: Database) async throws {
        let categories = try await Category.query(on: database).all()
        
        // We don't need to add categories when they has been already added.
        // This also prevent to recreate category when someone deleted standard one.
        if categories.count > 0 {
            return
        }
        
        let catagoryNames = [
            "Abstract": ["abstract"],
            "Aerial": ["aerial", "drone"],
            "Animals": ["animals", "animal", "pet", "pets", "cat", "cats", "dog", "dogs"],
            "Celebrities": ["celebrities", "celebrity"],
            "Architecture": ["architecture", "city"],
            "Commercial": ["commercial", "ads"],
            "Concert": ["concert"],
            "Family": ["family"],
            "Fashion": ["fashion", "model"],
            "Fine Art": ["fineart"],
            "Food": ["food"],
            "Journalism": ["journalism"],
            "Landscapes": ["landscapes", "landscape", "landscapephotography", "mountain", "mountains"],
            "Macro": ["macro"],
            "Nature": ["nature", "trees", "forest"],
            "Night": ["night"],
            "Nude": ["nude", "porn", "act", "nudity", "artnude", "fineartnude", "nudeart", "nudemodel"],
            "People": ["people", "person", "silhouette", "portrait", "character", "woman", "female", "man", "male", "girl"],
            "Sport": ["sport", "football", "tenis", "soccer"],
            "Still Life": ["still", "stilllife"],
            "Street": ["street", "streetphotography"],
            "Transportation": ["transportation", "car", "tram", "train"],
            "Travel": ["travel"],
            "Wedding": ["wedding"],
            "Other": []
        ]
        
        for categoryName in catagoryNames {
            let category = try await ensureCategoryExists(on: database, existing: categories, name: categoryName.key);
            try await ensureCategoryHashtagsExists(on: database, category: category, hashtags: categoryName.value)
        }
    }
    
    /// Emails that are temporary. Fresh list can be found here: https://github.com/disposable-email-domains/disposable-email-domains.
    private func disposableEmails(on database: Database) async throws {
        if self.environment == .testing {
            self.logger.notice("Disposable emails are not initialized during testing (testing environment is set).")
            return
        }
        
        self.logger.info("Disposable emails have to be added to the database, this may take a while.")
        let dispisableEmailsPath = self.directory.resourcesDirectory.finished(with: "/") + "disposable-emails.txt"
        
        guard let fileHandle = FileHandle(forReadingAtPath: dispisableEmailsPath) else {
            self.logger.notice("File with disposable emails cannot be opened ('\(dispisableEmailsPath)').")
            return
        }
        
        guard let fileData = try fileHandle.readToEnd() else {
            self.logger.notice("Cannot read file with disposable emails ('\(dispisableEmailsPath)').")
            return
        }
        
        guard let disposableEmailsString = String(data: fileData, encoding: .utf8) else {
            self.logger.notice("Cannot create string from file data ('\(dispisableEmailsPath)').")
            return
        }
        
        let dispisableEmailsLines = disposableEmailsString.split(separator: "\n")
        
        let amountInDatabase = try await DisposableEmail.query(on: database).count()
        if amountInDatabase == dispisableEmailsLines.count {
            self.logger.info("All disposable emails has been already added to the database.")
            return
        }
        
        try await dispisableEmailsLines.asyncForEach { line in
            try await ensureDisposableEmailExists(on: database, domain: String(line))
        }
        
        self.logger.info("All disposable emails added.")
    }
    
    private func ensureSettingExists(on database: Database, existing settings: [Setting], key: SettingKey, value: SettingValue) async throws {
        if !settings.contains(where: { $0.key == key.rawValue }) {
            let id = self.services.snowflakeService.generate()
            let setting = Setting(id: id, key: key.rawValue, value: value.value())
            _ = try await setting.save(on: database)
        }
    }
    
    private func deleteSetting(on database: Database, key: SettingKey) async throws {
        try await Setting.query(on: database)
            .filter(\.$key == key.rawValue)
            .delete()
    }

    private func ensureRoleExists(on database: Database,
                                  existing roles: [Role],
                                  code: String,
                                  title: String,
                                  description: String,
                                  isDefault: Bool) async throws {
        if !roles.contains(where: { $0.code == code }) {
            let id = self.services.snowflakeService.generate()
            let role = Role(id: id, code: code, title: title, description: description, isDefault: isDefault)
            _ = try await role.save(on: database)
        }
    }
    
    private func ensureCountryExists(on database: Database, existing countries: [Country], code: String, name: String) async throws {
        if !countries.contains(where: { $0.code == code }) {
            let id = self.services.snowflakeService.generate()
            let country = Country(id: id, code: code, name: name)
            _ = try await country.save(on: database)
        }
    }
    
    private func ensureLicenseExists(on database: Database, existing licenses: [License], code: String, name: String, description: String, url: String?) async throws {
        if !licenses.contains(where: { $0.name == name }) {
            let id = self.services.snowflakeService.generate()
            let license = License(id: id, name: name, code: code, description: description, url: url)
            _ = try await license.save(on: database)
        }
    }
    
    private func ensureCategoryExists(on database: Database, existing categories: [Category], name: String) async throws -> Category {
        guard let category = categories.first(where: { $0.name == name }) else {
            let id = self.services.snowflakeService.generate()
            let newCategory = Category(id: id, name: name, priority: 0)
            try await newCategory.save(on: database)
            
            return newCategory
        }
        
        return category
    }
    
    private func ensureCategoryHashtagsExists(on database: Database, category: Category, hashtags: [String]) async throws {
        for hashtag in hashtags {
            if try await CategoryHashtag.query(on: database)
                .filter(\.$category.$id == category.requireID())
                .filter(\.$hashtag == hashtag)
                .first() == nil {
                let id = self.services.snowflakeService.generate()
                let catagoryHashtag = try CategoryHashtag(id: id, categoryId: category.requireID(), hashtag: hashtag)
                _ = try await catagoryHashtag.save(on: database)
            }
        }
    }
    
    private func ensureAdminExist(on database: Database) async throws {
        let admin = try await User.query(on: database).filter(\.$userName == "admin").first()
        
        if admin == nil {
            let appplicationSettings = self.settings.cached

            let domain = appplicationSettings?.domain ?? "localhost"
            let baseAddress = appplicationSettings?.baseAddress ?? "http://\(domain)"
            
            let salt = VernissageServer.Password.generateSalt()
            let passwordHash = try VernissageServer.Password.hash("admin", withSalt: salt)
            let emailConfirmationGuid = UUID.init().uuidString
            let gravatarHash = UsersService().createGravatarHash(from: "admin@\(domain)")
            
            let (privateKey, publicKey) = try CryptoService().generateKeys()
            
            let newUserId = self.services.snowflakeService.generate()
            let user = User(id: newUserId,
                            type: .person,
                            url: "\(baseAddress)/@admin",
                            isLocal: true,
                            userName: "admin",
                            account: "admin@\(domain)",
                            activityPubProfile: "\(baseAddress)/actors/admin",
                            email: "admin@\(domain)",
                            name: "Administrator",
                            password: passwordHash,
                            salt: salt,
                            emailWasConfirmed: true,
                            isBlocked: false,
                            locale: "en_US",
                            emailConfirmationGuid: emailConfirmationGuid,
                            gravatarHash: gravatarHash,
                            privateKey: privateKey,
                            publicKey: publicKey,
                            isApproved: true,
                            publishedAt: Date())

            _ = try await user.save(on: database)

            if let administratorRole = try await Role.query(on: database).filter(\.$code == Role.administrator).first() {
                let id = self.services.snowflakeService.generate()
                let userRole = try UserRole(id: id, userId: user.requireID(), roleId: administratorRole.requireID())
                try await userRole.save(on: database)
            }
        }
    }
    
    private func localizables(on database: Database) async throws {
        let localizables = try await Localizable.query(on: database).all()
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.confirmEmail.subject",
                                          locale: "en_US",
                                          system: "\(Constants.name) - Confirm email")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.confirmEmail.body",
                                          locale: "en_US",
                                          system:
"""
<html>
    <body>
        <div>Hi {name},</div>
        <div>Please confirm your account by clicking following <a href='{redirectBaseUrl}confirm-email?token={token}&user={userId}'>link</a>.</div>
    </body>
</html>
""")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.forgotPassword.subject",
                                          locale: "en_US",
                                          system: "\(Constants.name) - Reset password")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.forgotPassword.body",
                                          locale: "en_US",
                                          system:
"""
<html>
    <body>
        <div>Hi {name},</div>
        <div>You can reset your password by clicking following <a href='{redirectBaseUrl}reset-password?token={token}'>link</a>.</div>
    </body>
</html>
""")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.archiveReady.subject",
                                          locale: "en_US",
                                          system: "\(Constants.name) - Archive is ready")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.archiveReady.body",
                                          locale: "en_US",
                                          system:
"""
<html>
    <body>
        <div>Hi {name},</div>
        <div>Your archive is ready to <a href='{archiveUrl}'>download</a>.</div>
    </body>
</html>
""")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.sharedBusinessCard.subject",
                                          locale: "en_US",
                                          system: "\(Constants.name) - Business card has been shared with you")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.sharedBusinessCard.body",
                                          locale: "en_US",
                                          system:
"""
<html>
    <body>
        <div>Hi {name},</div>
        <div>The photographer has shared their business card with you. You can access it at this <a href='{cardUrl}'>link</a>. It is private and visible only to you and the photographer.</div>
    </body>
</html>
""")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.confirmEmail.subject",
                                          locale: "pl_PL",
                                          system: "\(Constants.name) - Confirm email")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.confirmEmail.body",
                                          locale: "pl_PL",
                                          system:
"""
<html>
    <body>
        <div>Cześć {name},</div>
        <div>Potwierdź swój adres email poprzez kliknięcie w <a href='{redirectBaseUrl}confirm-email?token={token}&user={userId}'>link</a>.</div>
    </body>
</html>
""")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.forgotPassword.subject",
                                          locale: "pl_PL",
                                          system: "\(Constants.name) - Zresetuj hasło")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.forgotPassword.body",
                                          locale: "pl_PL",
                                          system:
"""
<html>
    <body>
        <div>Cześć {name},</div>
        <div>Możesz ustawić nowe hasło po kliknięciu w <a href='{redirectBaseUrl}reset-password?token={token}'>link</a>.</div>
    </body>
</html>
""")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.archiveReady.subject",
                                          locale: "pl_PL",
                                          system: "\(Constants.name) - Archiwum gotowe")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.archiveReady.body",
                                          locale: "pl_PL",
                                          system:
"""
<html>
    <body>
        <div>Cześć {name},</div>
        <div>Twoje archiwum jest gotowe do <a href='{archiveUrl}'>pobrania</a>.</div>
    </body>
</html>
""")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.sharedBusinessCard.subject",
                                          locale: "pl_PL",
                                          system: "\(Constants.name) - Udostępniono nową wizytówkę")
        
        try await ensureLocalizableExists(on: database,
                                          existing: localizables,
                                          code: "email.sharedBusinessCard.body",
                                          locale: "pl_PL",
                                          system:
"""
<html>
    <body>
        <div>Cześć {name},</div>
        <div>Fotograf udostępnił z tobą swoją wizytówkę. Masz do niej dostęp pod tym <a href='{cardUrl}'>adresem</a>. Jest ona prywatna widoczna tylko dla ciebie oraz dla fotografa.</div>
    </body>
</html>
""")
    }
    
    private func ensureLocalizableExists(on database: Database,
                                         existing localizables: [Localizable],
                                         code: String,
                                         locale: String,
                                         system: String) async throws {
        if !localizables.contains(where: { $0.code == code && $0.locale == locale }) {
            let id = self.services.snowflakeService.generate()
            let localizable = Localizable(id: id, code: code, locale: locale, system: system)
            _ = try await localizable.save(on: database)
        }
    }
    
    private func ensureDisposableEmailExists(on database: Database, domain: String) async throws {
        let domainNormalized = domain.uppercased()
        let disposableEmailFromDatabase = try await DisposableEmail.query(on: database)
            .filter(\.$domainNormalized == domainNormalized)
            .first()

        if disposableEmailFromDatabase != nil {
            return
        }
        
        let id = self.services.snowflakeService.generate()
        let disposableEmail = DisposableEmail(id: id, domain: domain)
        _ = try await disposableEmail.save(on: database)
    }
}
