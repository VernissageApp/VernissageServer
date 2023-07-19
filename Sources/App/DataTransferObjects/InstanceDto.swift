//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct InstanceDto {
    var uri: String
    var title: String
    var description: String
    var email: String
    var version: String
    var thumbnail: String
    var languages: [String]
    var rules: [String]
    
    var registrationOpened: Bool
    var registrationByApprovalOpened: Bool
    var registrationByInvitationsOpened: Bool
    
    var configuration: ConfigurationDto
    var stats: InstanceStatisticsDto
    var contact: UserDto?
}

extension InstanceDto: Content { }

/*
{
    "uri": "mastodon.social",
    "title": "Mastodon",
    "short_description": "The original server operated by the Mastodon gGmbH non-profit",
    "description": "",
    "email": "staff@mastodon.social",
    "version": "4.1.4+nightly-20230718",
    "urls": {
        "streaming_api": "wss://streaming.mastodon.social"
    },
    "stats": {
        "user_count": 1444811,
        "status_count": 61142569,
        "domain_count": 58976
    },
    "thumbnail": "https://files.mastodon.social/site_uploads/files/000/000/001/@1x/57c12f441d083cde.png",
    "languages": [
        "en"
    ],
    "registrations": true,
    "approval_required": false,
    "invites_enabled": true,
    "configuration": {
        "accounts": {
            "max_featured_tags": 10
        },
        "statuses": {
            "max_characters": 500,
            "max_media_attachments": 4,
            "characters_reserved_per_url": 23
        },
        "media_attachments": {
            "supported_mime_types": [
                "image/jpeg",
                "image/png",
                "image/gif",
                "image/heic",
                "image/heif",
                "image/webp",
                "image/avif",
                "video/webm",
                "video/mp4",
                "video/quicktime",
                "video/ogg",
                "audio/wave",
                "audio/wav",
                "audio/x-wav",
                "audio/x-pn-wave",
                "audio/vnd.wave",
                "audio/ogg",
                "audio/vorbis",
                "audio/mpeg",
                "audio/mp3",
                "audio/webm",
                "audio/flac",
                "audio/aac",
                "audio/m4a",
                "audio/x-m4a",
                "audio/mp4",
                "audio/3gpp",
                "video/x-ms-asf"
            ],
            "image_size_limit": 16777216,
            "image_matrix_limit": 33177600,
            "video_size_limit": 103809024,
            "video_frame_rate_limit": 120,
            "video_matrix_limit": 8294400
        },
        "polls": {
            "max_options": 4,
            "max_characters_per_option": 50,
            "min_expiration": 300,
            "max_expiration": 2629746
        }
    },
    "contact_account": {
        "id": "13179",
        "username": "Mastodon",
        "acct": "Mastodon",
        "display_name": "Mastodon",
        "locked": false,
        "bot": false,
        "discoverable": true,
        "group": false,
        "created_at": "2016-11-23T00:00:00.000Z",
        "note": "<p>Official account of the Mastodon project. News, releases, announcements! Learn more on our website!</p>",
        "url": "https://mastodon.social/@Mastodon",
        "avatar": "https://files.mastodon.social/accounts/avatars/000/013/179/original/b4ceb19c9c54ec7e.png",
        "avatar_static": "https://files.mastodon.social/accounts/avatars/000/013/179/original/b4ceb19c9c54ec7e.png",
        "header": "https://files.mastodon.social/accounts/headers/000/013/179/original/878f382e7dd9fb84.png",
        "header_static": "https://files.mastodon.social/accounts/headers/000/013/179/original/878f382e7dd9fb84.png",
        "followers_count": 794746,
        "following_count": 7,
        "statuses_count": 241,
        "last_status_at": "2023-07-06",
        "noindex": false,
        "emojis": [],
        "roles": [],
        "fields": [
            {
                "name": "Homepage",
                "value": "<a href=\"https://joinmastodon.org\" target=\"_blank\" rel=\"nofollow noopener noreferrer me\" translate=\"no\"><span class=\"invisible\">https://</span><span class=\"\">joinmastodon.org</span><span class=\"invisible\"></span></a>",
                "verified_at": "2018-10-31T04:11:00.076+00:00"
            },
            {
                "name": "Patreon",
                "value": "<a href=\"https://patreon.com/mastodon\" target=\"_blank\" rel=\"nofollow noopener noreferrer me\" translate=\"no\"><span class=\"invisible\">https://</span><span class=\"\">patreon.com/mastodon</span><span class=\"invisible\"></span></a>",
                "verified_at": null
            },
            {
                "name": "GitHub",
                "value": "<a href=\"https://github.com/mastodon\" target=\"_blank\" rel=\"nofollow noopener noreferrer me\" translate=\"no\"><span class=\"invisible\">https://</span><span class=\"\">github.com/mastodon</span><span class=\"invisible\"></span></a>",
                "verified_at": null
            }
        ]
    },
    "rules": [
        {
            "id": "1",
            "text": "Sexually explicit or violent media must be marked as sensitive when posting"
        },
        {
            "id": "2",
            "text": "No racism, sexism, homophobia, transphobia, xenophobia, or casteism"
        },
        {
            "id": "3",
            "text": "No incitement of violence or promotion of violent ideologies"
        },
        {
            "id": "4",
            "text": "No harassment, dogpiling or doxxing of other users"
        },
        {
            "id": "7",
            "text": "Do not share intentionally false or misleading information"
        }
    ]
}
*/
