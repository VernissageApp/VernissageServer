# Vernissage API server

![Build Status](https://github.com/VernissageApp/VernissageServer/workflows/Build/badge.svg)
[![Swift 5.8](https://img.shields.io/badge/Swift-5.8-orange.svg?style=flat)](ttps://developer.apple.com/swift/)
[![Vapor 4](https://img.shields.io/badge/vapor-4.0-blue.svg?style=flat)](https://vapor.codes)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![Platforms macOS | Linux](https://img.shields.io/badge/Platforms-macOS%20%7C%20Linux%20-lightgray.svg?style=flat)](https://developer.apple.com/swift/)

Application which is main API component for Vernissage.

## Prerequisites

Install the GD library on your computer. If you're using macOS, install Homebrew then run the command `brew install gd`.
If you're using Linux, run `apt-get libgd-dev` as root.

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
- [x] Return HTML as flexi-fields
- [x] Build mechanism for flexi-fields URL validation
- [x] Connect user to Hashtags based on description (bio)
- [x] Create HTML version of bio (hashtags/urls)
- [x] Markdown support in bio
- [x] Save status
- [x] List of statuses (different for different users)
- [x] Upload/update/delete attachments (tests)
- [x] Save status (tests)
- [x] List of statuses (tests)
- [x] Delete status (tests)
- [x] Countries (tests)
- [x] Locations (tests)
- [x] Instance controller (base information)
- [x] Disable registration when system settings is set
- [x] Add reason/invitation code to the registration page
- [x] Fix email from/name

**Storage**

- [x] Save images in S3 file storage (key/secret/address/bucket)
- [x] Delete files (and attachments) which are not connected to status and has been added few hours ago

**ActivityPub**

- [x] Follow API (with sending to the Fediverse server via ActivityPub)
- [x] Unfollow API (with sending to the Fediverse server via ActivityPub)
- [x] Follow from ActivityPub
- [x] Unfollow from ActivityPub
- [x] Verify security headers in ActivityPub requests
- [x] Verify if algorithm is supported: algorithm=\"rsa-sha256\"
- [x] Verify if domain is not blocked in ActivityPub requests 
- [x] Sending new status to remote servers (followers and mentioned)
- [x] Sending boost status to remote servers (annouce)
- [ ] Add list with known domains (fediversed)
- [ ] Deleting the user based on shared inbox queue
- [ ] Deleting user from remote server
- [ ] Deleting status from remote server
- [ ] Unboost status from remote server

**API**

- [x] User relationships API
- [x] Create unit tests for relationship API
- [x] Create unit tests for follow requests API
- [x] Create unit tests for users follow/unfollow API
- [x] Create followers API
- [x] Create following API
- [x] Create unit tests for user's statuses
- [x] Statuses API (with MediaAttachments and Hashtags from note)
- [x] Mentions on status
- [x] Timeline API (home/public with min_id, max_id etc.)
- [x] Boost status API
- [x] Unboost status API
- [x] Favourite/unfavourite status API
- [x] Bookmark/unbookmark status API
- [x] Instance API (advance data)
- [x] Location in status data API
- [ ] Save internal server errors into logs
- [ ] Unit tests announce ActivityPub
- [ ] Unit tests create ActivityPub
- [ ] Add more tests for deleting user (connected with favourite/bookmark/reblog etc.)

**Notifications**

- [x] List of notifications API
- [ ] Add notification when user is follwing the account
- [x] Notification: 'mention'. Someone mentioned you in their status.
- [ ] Notification: 'status'. Someone you enabled notifications for has posted a status.
- [x] Notification: 'reblog'. Someone boosted one of your statuses.
- [x] Notification: 'follow'. Someone followed you.
- [x] Notification: 'followRequest'. Someone requested to follow you.
- [x] Notification: 'favourite'. Someone favourited one of your statuses.
- [ ] Notification: 'update'. A status you boosted with has been edited.
- [ ] Notification: 'adminSignUp'. Someone signed up (optionally sent to admins).
- [ ] Notification: 'adminReport'. A new report has been filed.
