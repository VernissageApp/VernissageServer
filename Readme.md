# Vernissage API server

![Build Status](https://github.com/Vernissage/VernissageServer/workflows/Build/badge.svg)
[![Swift 5.8](https://img.shields.io/badge/Swift-5.8-orange.svg?style=flat)](ttps://developer.apple.com/swift/)
[![Vapor 4](https://img.shields.io/badge/vapor-4.0-blue.svg?style=flat)](https://vapor.codes)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![Platforms macOS | Linux](https://img.shields.io/badge/Platforms-macOS%20%7C%20Linux%20-lightgray.svg?style=flat)](https://developer.apple.com/swift/)

Application which is main API component for Vernissage.

## Architecture

```
                  +-----------------------+
                  |     VernissageAPI     |
                  +----------+------------+
                             |
         +-------------------+-------------------+
         |                   |                   |
+--------+--------+   +------+------+   +--------+-----------+
|   PostgreSQL    |   |    Redis    |   |  ObjectStorage S3  |
+-----------------+   +-------------+   +--------------------+
```

## Things todo:

- [x] Sending the emails from the application (via Jobs)
- [x] Change id into Snowflake'ish one
- [x] Change to new Vapor structure
- [x] Save external profile resources in the internal storage
- [x] Add missing unit tests

**Improved registrations**:

- [x] Add more properties to the user table: header (URL), statusesCount (Int), followersCount (Int), followingCount (Int).
- [x] Open registrations (with email confirmation)
- [x] Resending email confirmation
- [x] Registrations via invitations
- [x] Registrations via approval

**Improve user data**

- [x] Add user fields (for user specific information key/value)
- [ ] Connect user to Hashtags based on description (bio)

**ActivityPub**

- [ ] Deleting the user based on shared inbox queue (via Jobs)
- [ ] Follow API (with sending to the Fediverse server via ActivityPub)
- [ ] Unfollow API (with sending to the Fediverse server via ActivityPub)
- [ ] Follow from ActivityPub
- [ ] Unfollow from ActivityPub

**API**

- [ ] Instance API
- [ ] Statuses API (with MediaAttachments and Hashtags from note)

**External resources**

- [ ] Send internal resource to the CDN
