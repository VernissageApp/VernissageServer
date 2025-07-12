//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Basic constants used in the system.
public final class Constants {
    public static let name = "Vernissage"
    public static let version = "1.19.0-buildx"
    public static let applicationName = "\(Constants.name) \(Constants.version)"
    public static let userAgent = "(\(Constants.name)/\(Constants.version))"
    public static let requestMetadata = "Request body"
    public static let twoFactorTokenHeader = "X-Auth-2FA"
    public static let xsrfTokenHeader = "X-XSRF-TOKEN"
    public static let imageQuality = 85
    public static let imageSizeLimit = 10_485_760
    public static let statusMaxCharacters = 500
    public static let statusMaxMediaAttachments = 4
    public static let statusCharactersReservedPerUrl = 23
    public static let accessTokenName = "access-token"
    public static let refreshTokenName = "refresh-token"
    public static let xsrfTokenName = "xsrf-token"
    public static let isMachineTrustedName = "is-machine-trusted"

    public static let jrdJsonContentType: HTTPMediaType = .init(type: "application", subType: "jrd+json", parameters: ["charset": "utf-8"])
    public static let xrdXmlContentType: HTTPMediaType = .init(type: "application", subType: "xrd+xml", parameters: ["charset": "utf-8"])
    public static let activityJsonContentType: HTTPMediaType = .init(type: "application", subType: "activity+json", parameters: ["charset": "utf-8"])
    
    public static let defaultPrivacyPolicy = """
This Privacy Policy explains how **{{hostname}}** (”{{hostname}},” “we,” “our,” or “us”) processes, protects, and uses your personal data that may be collected through our website or API. It also outlines your rights regarding access, updates, and deletion of your personal information. This policy applies exclusively to the services provided by **{{hostname}}** and does not cover the practices of other companies or individuals not affiliated with us.

## What information do we collect?

- **Basic account information**: If you register on this server, you will be required to provide a username, an email address, and a password. You may also choose to provide additional profile information, such as a display name or a biography, and upload a profile picture or header image. Please note that your username, display name, biography, profile picture, and header image will always be publicly visible.

- **Posts, Following, and Other Public Information**: The list of people you follow is publicly visible, and your followers are also publicly listed. When you submit a message, we store the date and time of submission, as well as the application you used. Messages may contain media attachments, such as images. Public and unlisted posts are publicly accessible. When you feature a post on your profile, it becomes publicly available. Your posts are delivered to your followers; in some cases, this means they are transmitted to different servers, where copies may be stored. When you delete a post, a corresponding deletion request is sent to your followers (and potentially to any other servers hosting that post). The action of reblogging (or favoriting) another post is always public.

- **Direct and Followers-Only Posts**: All posts are stored and processed on this server. Followers-only posts are delivered to your followers and to any users mentioned in those posts, while direct posts are delivered only to the mentioned users. In some cases, this means the posts may be delivered to other servers, where copies could be stored. We make a good-faith effort to ensure that only authorized recipients have access to these posts, but other servers may not maintain the same standards. Therefore, it is important to review the servers your followers use. You can enable an option in your settings to manually approve or reject new followers. Please be aware that both the operators of this server and any receiving servers may view such messages, and recipients can screenshot, copy, or otherwise redistribute them. We strongly advise against sharing any sensitive information via Vernissage.

- **IPs and other metadata**: We do not store IP addresses in our database. However, our hosting provider may collect and retain IP addresses as part of their standard server operations or for security purposes. We may also capture IP addresses in server logs, but we only keep those logs for up to 12 months. Additionally, we do not store user sessions, so session history is not available for review.

## What do we use your information for?

Any information we collect from you may be used in the following ways:

- To provide the core functionality of Vernissage. You can only interact with other people’s content and post your own content when you are logged in. For example, you may follow other people to view their combined posts in your personalized home timeline.
- To aid moderation of the community. For example, user reports with descriptions can help us provide better service.
- The email address you provide may be used to send you information, notifications about interactions with your content or messages from other users, and to respond to inquiries or other requests.

## How do we protect your information?

We implement a variety of security measures to protect your personal information whenever you enter, submit, or access it. For example, your browser session and all traffic between your devices and the API are encrypted using SSL, and your password is hashed with a robust one-way algorithm. Additionally, you can enable two-factor authentication to further secure your account.

## What is our data retention policy?

We store server logs that may include your IP address for up to 12 months, after which they are automatically removed from our systems. You can also request and download an archive of your content - this includes your posts, media attachments, profile picture, and header image.

You may irreversibly delete your account at any time. When you do, we also send a removal request to all other servers known to this application, asking them to delete your account data if it was previously shared with them. However, we cannot guarantee that these servers will comply with the request.


## Do we use cookies?

Yes, but only for user session.

## Do we disclose any information to outside parties?

We do not sell, trade, or otherwise transfer your personal information to outside parties. However, we may disclose your data if we deem it necessary to comply with the law, enforce our site policies, or protect our rights, property, or safety, as well as the rights, property, or safety of others.

Your public content may be downloaded by other servers in the network. Your public and followers-only posts are delivered to the servers where your followers reside, and direct messages are delivered to the servers of the recipients, provided those followers or recipients are on a different server than this one.

When you authorize an application to use your account, it may access your public profile information, your following list, your followers, your lists, all of your posts, and your favorites, depending on the permissions you grant. However, applications can never access your email address or password.

## Machine learning (AI)

Images uploaded by users may be processed using machine learning (AI) to generate descriptions that assist people with disabilities or to create hashtag suggestions. This processing occurs **ONLY** upon the user’s request when they initiate the appropriate action in the system. We use OpenAI technology for this purpose. According to OpenAI’s assurances, uploaded images are immediately deleted after processing and are not used to train their models. Users retain full control over which images are processed, as the process is initiated solely by their actions. For more details about OpenAI’s data policies, please refer to the official documentation available on OpenAI’s website.

## Site usage by children

If this server is in the EU or the EEA: Our site, products, and services are intended for individuals who are at least 16 years old. Under the requirements of the GDPR (General Data Protection Regulation), if you are under 16, you must not use this site.

If this server is in the USA: Our site, products, and services are intended for individuals who are at least 13 years old. Under the requirements of COPPA (Children’s Online Privacy Protection Act), if you are under 13, you must not use this site.

Law requirements can be different if this server is in another jurisdiction.

*This document is CC-BY-SA. Originally adapted from the Mastodon privacy policy.*
"""
    
    public static let defaultTermsOfService = """
## 1. Introduction

Our aim is to keep this Agreement as readable as possible, but in some cases for legal reasons, some of the language is required "legalese".

## 2. Your Acceptance of this Agreement

These Terms of Service (“Terms”) constitute an agreement between You and **{{hostname}}** (“{{hostname}},” “we,” “our,” or “us”). The following terms and conditions, along with any documents expressly incorporated by reference (collectively, the “Terms of Service”), govern your access to and use of **{{hostname}}**, including any content, functionality, and services offered on or through **{{hostname}}** (the “Website”).

Please read these Terms of Service carefully before you start to use the Website.

By using the Website, you accept and agree to be bound by these Terms of Service and our Privacy Policy, found at <a href="/privacy">privacy</a> and incorporated herein by reference. If you do not agree to these Terms of Service, you must not access or use the Website.

You must be at least 13 years old to use this Website. However, children of all ages may use the Website if enabled by a parent or legal guardian. If you are under 18, you represent that you have permission from your parent or guardian to use the Website. Please have them read these Terms of Service with you. If you are a parent or legal guardian of a user under 18, by allowing your child to use the Website, you agree to these Terms of Service and accept responsibility for your child’s activity on the Website.

BY ACCESSING AND USING THIS WEBSITE, YOU:

1. ACCEPT AND AGREE TO BE BOUND BY AND COMPLY WITH THESE TERMS OF SERVICE;
2. REPRESENT AND WARRANT THAT YOU ARE OF LEGAL AGE OF MAJORITY UNDER APPLICABLE LAW TO ENTER INTO A BINDING CONTRACT WITH US; AND
3. AGREE THAT IF YOU ACCESS THE WEBSITE FROM A JURISDICTION WHERE SUCH ACCESS IS PROHIBITED, YOU DO SO AT YOUR OWN RISK.

## 3. Updates to Terms of Service

We may revise and update these Terms of Service in our sole discretion from time to time. All changes become effective immediately upon posting and apply to all subsequent access and use of the Website. By continuing to use the Website after the revised Terms of Service have been posted, you accept and agree to those changes. You are expected to check this page each time you access the Website so that you are aware of any modifications, as they are binding on you.

## 4. Your Responsibilities

You must ensure that all individuals who access the Website through your account or device are aware of this Agreement and comply with it. It is a condition of your use of the Website that all information you provide is accurate, current, and complete.

YOU ARE SOLELY AND ENTIRELY RESPONSIBLE FOR YOUR USE OF THE WEBSITE AND FOR THE SECURITY OF YOUR COMPUTER, INTERNET CONNECTION, AND DATA.


## 5. Prohibited Activities

You may use the Website only for lawful purposes and in accordance with these Terms of Service. You agree not to use the Website in any way that violates any of the following rules:

{{rules}}

Additionally, you agree not to:
- Use the Website in any manner that could disable, overburden, damage, or impair it, or interfere with any other user’s ability to engage in real-time activities on the Website.
- Use any device, software, or routine that interferes with the proper functioning of the Website.
- Introduce any viruses, Trojan horses, worms, logic bombs, or other material that is malicious or technologically harmful.
- Attempt to gain unauthorized access to, interfere with, damage, or disrupt any parts of the Website, the server on which it is hosted, or any server, computer, or database connected to the Website.
- Attack the Website via a denial-of-service attack or a distributed denial-of-service attack.
- Otherwise attempt to interfere with the proper functioning of the Website.

## 6. Our Rights

We reserve the right, without prior notice, to:
- Take appropriate legal action, including, without limitation, referring matters to or cooperating with law enforcement or regulatory authorities, or informing a harmed party of any illegal or unauthorized use of the Website.
- Terminate or suspend your access to all or part of the Website for any or no reason, including, without limitation, any violation of these Terms of Service.


## 7. Third-Party Links and Content

For your convenience, this Website may provide links or references to third-party sites or content. We make no representations about any external websites or third-party content that may be accessed from this Website. If you choose to access these sites, you do so at your own risk. We have no control over third-party content or such websites and accept no responsibility for any loss or damage that may arise from your use of them. You are subject to the terms and conditions of any third-party sites you visit.

## 8. Machine learning (AI)

Our website allows the processing of images using machine learning (AI) to generate descriptions that assist people with disabilities and to create hashtag suggestions. This functionality is available only upon the user’s request and requires the initiation of an appropriate action in the system.

The processing of images is carried out using OpenAI technology. As per OpenAI’s assurances, uploaded images are immediately deleted after processing and are not used to train their models. Users maintain full control over the process and decide which images are processed. For further details regarding OpenAI’s data handling and privacy practices, please consult the official documentation on OpenAI’s website.

## 9. Privacy Policy

Your provision of personal information through the Website is governed by our privacy policy located at <a href="/privacy">privacy</a> (the "Privacy Policy").

            
## 10. Severability

If any provision of these Terms of Service is illegal or unenforceable under applicable law, the remainder of the provision will be amended to achieve as closely as possible the effect of the original term and all other provisions of these Terms of Service will continue in full force and effect.

            
## 11. Waiver

No failure to exercise, and no delay in exercising, on the part of either party, any right or any power hereunder shall operate as a waiver thereof, nor shall any single or partial exercise of any right or power hereunder preclude further exercise of that or any other right hereunder.

## 12. Notice
We may provide any notice to you under these Terms of Service by: (i) sending a message to the email address you provide to us and consent to us using; or (ii) by posting to the Website. Notices sent by email will be effective when we send the email and notices we provide by posting will be effective upon posting. It is your responsibility to keep your email address current.

To give us notice under these Terms of Service, you must contact us as by send email to: {{email}}.
"""
}
