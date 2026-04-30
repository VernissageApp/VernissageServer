# ActivityPub

A decentralized social networking protocol based upon the ActivityStreams 2.0 data format and JSON-LD.

- [Discovery and security](#Discovery-and-security)
- [Status federation](#Status-federation)
- [Profile federation](#Profile-federation)
- [Reports (Flag)](#Reports-Flag)
- [Extensions](#Extensions)

## Discovery and security

Vernissage expects ActivityPub actors to be resolvable and authenticated using standard Fediverse mechanisms.

### WebFinger

Actors are identified by `username@domain` and resolved through WebFinger (`acct:` URI).  
Implementation details are documented in [WebFinger](WebFinger.md).

### HTTP Signatures

Vernissage signs outbound ActivityPub requests and validates signatures for inbound inbox requests.  
Inbound POST requests are expected to be signed and validated before processing.

Detailed verification and signing rules are documented in [HTTP Security](HttpSecurity.md).

### NodeInfo

Vernissage exposes NodeInfo discovery endpoints (`/.well-known/nodeinfo`) and NodeInfo documents for instance metadata exchange.

## Status federation

Supported activities for statuses (photos):

- `Create` - transformed info status and saved into database.
- `Delete` - removes a status from database.
- `Like` - transformed into a favourite on a status.
- `Announce` - transformed into a boost on a status.
- `Undo` - undo a previous `Like` or `Annouce`.

### Schema

Vernissage supports only object type `Note`. Notes are transformed into regular statuses (photos). 

> Note: Vernissage can only display notes that include images in the attachment collection.

Notes without any images are not saved to the database. However, if a note is a reply to a previously fetched note (which must include an image), it will be saved to the database.

Used properties:

- `id` - saved as ActivityPub object identifier.
- `content` - used as a status text.
- `summary` - used as content warning text.
- `inReplyTo` - used for threading a status as a reply to another status.
- `published` - used as status date.
- `url` - used for status permalinks.
- `attributedTo` - used to determine the profile which authored the status.
- `to`/`cc` - used to determine audience and visibility of a status, in combination with mentions.
- `sensitive` - used to determine whether status media or text should be hidden by default.
- `tag` - used to mark up mentions, hashtags or emojis (collection of `NoteTagDto`).
- `attachment` - used to include attached images (collection of `MediaAttachmentDto`).

Properties of `NoteTagDto`:

- `type` - either `Mention`, `Hashtag`, or `Emoji` is currently supported.
- `name` - the plain-text Webfinger address of a profile `Mention` (@user or @user@domain), or the plain-text `Hashtag` (#tag), or the custom `Emoji` shortcode (:thounking:).
- `href` - the URL of the actor or tag.
- `icon` - information about emoji (`NoteTagIconDto` object).
- `updated` - date when emoji has been updated.

Properties of `NoteTagIconDto`:

- `type` - type of the icon, `Image` is supported only.
- `mediaType` - mime type of the icon.
- `url` - url to the file icon.

Properties of `MediaAttachmentDto`:

- `url` - used to fetch the media attachment.
- `name` - used as media description (ALT text).
- `mediaType` - used to distinguish if attachment is an image.

Extensions in `MediaAttachmentDto`:

- `blurhash` - used to generate a blurred preview image corresponding to the colors used within the image (see: https://docs.joinmastodon.org/spec/activitypub/#blurhash)
- `exifData` - metadata information about the image (collection of `PropertyValue`, compatible with FEP-EE3A).
- `exif` - legacy metadata extension (see: https://joinvernissage.org/ns#exif), maintained for backward compatibility.
- `location` - extension from https://schema.org (extension: `addressCountry`, type: `Place`).
- `location.geonameId` - additional extension to location (see: https://joinvernissage.org/ns#geonameId).

### JSON+LD Example

```json
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    {
      "addressCountry": "schema:addressCountry",
      "blurhash": "toot:blurhash",
      "geonameId": "photos:geonameId",
      "Category": "photos:Category",
      "PropertyValue": "schema:PropertyValue",
      "photos": "https://joinvernissage.org/ns#",
      "schema": "https://schema.org/",
      "toot": "http://joinmastodon.org/ns#"
    }
  ],
  "attachment": [
    {
      "blurhash": "U1AJ~A_300_300009Fof?b4nIUt7xu%MD%4n",
      "exifData": [
        {
          "@type": "PropertyValue",
          "name": "DateTime",
          "value": "2025:02:27 17:38:49"
        },
        {
          "@type": "PropertyValue",
          "name": "ExposureTime",
          "value": "1/200"
        },
        {
          "@type": "PropertyValue",
          "name": "FNumber",
          "value": "f/2.2"
        },
        {
          "@type": "PropertyValue",
          "name": "FocalLength",
          "value": "85 mm"
        },
        {
          "@type": "PropertyValue",
          "name": "FocalLengthIn35mmFilm",
          "value": "85"
        },
        {
          "@type": "PropertyValue",
          "name": "LensModel",
          "value": "Zeiss Batis 1.8/85"
        },
        {
          "@type": "PropertyValue",
          "name": "Make",
          "value": "SONY"
        },
        {
          "@type": "PropertyValue",
          "name": "Model",
          "value": "ILCE-7M4"
        },
        {
          "@type": "PropertyValue",
          "name": "PhotographicSensitivity",
          "value": "3200"
        },
        {
          "@type": "PropertyValue",
          "name": "Flash",
          "value": "Flash did not fire, compulsory flash mode"
        },
        {
          "@type": "PropertyValue",
          "name": "GPSLatitude",
          "value": "51.110501666666664N"
        },
        {
          "@type": "PropertyValue",
          "name": "GPSLongitude",
          "value": "17.033457778333332E"
        }
      ],
      "height": 2731,
      "location": {
        "addressCountry": "PL",
        "geonameId": "3081368",
        "latitude": "51,1",
        "longitude": "17,03333",
        "name": "Wrocław",
        "type": "Place"
      },
      "mediaType": "image/jpeg",
      "name": "The image is in black and white, showing a cafe with tables and chairs.",
      "type": "Image",
      "url": "https://vernissage.instance/storage/eeb75ee9252a4f1192d8d66be2dcf962.jpg",
      "width": 4096
    }
  ],
  "attributedTo": "https://vernissage.instance/actors/johndoe",
  "cc": [
    "https://vernissage.photos/actors/mczachurski/followers"
  ],
  "content": "<p>Waiting...<br /><br /><a href=\"https://vernissage.instance/tags/Photography\" rel=\"tag\" class=\"mention hashtag\">#Photography</a> <a href=\"https://vernissage.instance/tags/Street\" rel=\"tag\" class=\"mention hashtag\">#Street</a> <a href=\"https://vernissage.instance/tags/StreetPhotography\" rel=\"tag\" class=\"mention hashtag\">#StreetPhotography</a> <a href=\"https://vernissage.instance/tags/BlackAndWhite\" rel=\"tag\" class=\"mention hashtag\">#BlackAndWhite</a> <a href=\"https://vernissage.instance/tags/BlackAndWhitePhotography\" rel=\"tag\" class=\"mention hashtag\">#BlackAndWhitePhotography</a></p>",
  "id": "https://vernissage.instance/actors/johndoe/statuses/7500892058677152209",
  "published": "2025-05-05T09:32:06.508Z",
  "sensitive": false,
  "tag": [
    {
      "href": "https://vernissage.instance/tags/BlackAndWhite",
      "name": "#BlackAndWhite",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/tags/BlackAndWhitePhotography",
      "name": "#BlackAndWhitePhotography",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/tags/Photography",
      "name": "#Photography",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/tags/Street",
      "name": "#Street",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/tags/StreetPhotography",
      "name": "#StreetPhotography",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/categories/Street",
      "name": "Street",
      "type": "Category"
    }
  ],
  "to": [
    "https://www.w3.org/ns/activitystreams#Public"
  ],
  "type": "Note",
  "url": "https://vernissage.instance/@johndoe/7500892058677152209"
}
```

## Profile federation

Supported activities for profiles:

- `Follow` - indicate interest in receiving status updates from a profile.
- `Accept`/`Reject` - used to approve or deny `Follow` activities. Unlocked accounts will automatically reply with an `Accept`, while locked accounts can manually choose whether to approve or deny a follow request.
- `Update` - refresh account details.
- `Delete` - remove an account from the database, as well as all of their statuses.
- `Undo` - Undo a previous `Follow`.
- `Move` - migrate followers from an old account to a new account.

### Schema

Used properties:
- `id` - saved as ActivityPub object identifier.
- `preferredUsername` - used for Webfinger lookup. Must be unique on the domain, and must correspond to a Webfinger acct: URI.
- `name` - used as profile display name.
- `summary` - used as a profile bio.
- `type` - assumed to be `Person`. If type is `Application` or `Service`, it will be interpreted as a bot flag.
- `url` - used as profile link.
- `icon` - used as profile avatar.
- `image` - used as profile header.
- `manuallyApprovesFollowers` - will be shown as a locked account.
- `publicKey` - required for signatures (object `PersonPublicKeyDto`).
- `attachment` - used for profile fields (collection of `PersonAttachmentDto`)
- `alsoKnownAs` - required for Move activity (collection of strings).
- `movedTo` - destination actor id used by account migration (`Move`) and exposed on actor `Person`.
- `tag` - used to mark up hashtags or emojis (collection of `PersonHashtagDto`).
- `published` - when the profile was created.
- `endpoints` - a json object which maps additional (typically server/domain-wide) endpoints which may be useful either for this actor or someone referencing this actor.
- `inbox` - a reference to an [ActivityStreams] OrderedCollection comprised of all the messages received by the actor.
- `outbox` - an [ActivityStreams] OrderedCollection comprised of all the messages produced by the actor.
- `following` - a link to an [ActivityStreams] collection of the actors that this actor is following.
- `followers` - a link to an [ActivityStreams] collection of the actors that follow this actor.

Properties of `PersonPublicKeyDto`:

- `id` - public key identifier.
- `owner` - url to public key owner.
- `publicKeyPem` - public key PEM.

Properties of `PersonAttachmentDto`:

- `type` - only `PropertyValue` extension from https://schema.org is supported.
- `name` - name of the property.
- `value` - value of the property.

Properties of `PersonHashtagDtoDto`:

- `name` - the plain-text `Hashtag` (#tag), or the custom `Emoji` shortcode (:thounking:).
- `href` - the URL of the tag.
- `icon` - information about emoji (`PersonImageDto` object).

Properties of `PersonImageDto`:

- `type` - type of the icon, `Image` is supported only.
- `mediaType` - mime type of the icon.
- `url` - url to the file icon.

### JSON+LD Example

```json
{
  "@context": [
    "https://w3id.org/security/v1",
    "https://www.w3.org/ns/activitystreams",
    {
      "PropertyValue": "schema:PropertyValue",
      "alsoKnownAs": {
        "@id": "as:alsoKnownAs",
        "@type": "@id"
      },
      "movedTo": {
        "@id": "as:movedTo",
        "@type": "@id"
      },
      "manuallyApprovesFollowers": "as:manuallyApprovesFollowers",
      "schema": "https://schema.org",
      "toot": "http://joinmastodon.org/ns#"
    }
  ],
  "alsoKnownAs": [
    "https://example.social/users/johndoe"
  ],
  "attachment": [
    {
      "name": "HOMEPAGE",
      "type": "PropertyValue",
      "value": "<a href=\"https://johndoe.dev\" rel=\"me nofollow noopener noreferrer\" class=\"url\" target=\"_blank\"><span class=\"invisible\">https://</span>johndoe.dev</a>"
    },
    {
      "name": "MASTODON",
      "type": "PropertyValue",
      "value": "<a href=\"https://example.social/@johndoe\" rel=\"me nofollow noopener noreferrer\" class=\"url\" target=\"_blank\"><span class=\"invisible\">https://</span>example.social/@johndoe</a>"
    }
  ],
  "endpoints": {
    "sharedInbox": "https://vernissage.photos/shared/inbox"
  },
  "followers": "https://vernissage.instance/actors/johndoe/followers",
  "following": "https://vernissage.instance/actors/johndoe/following",
  "icon": {
    "mediaType": "image/jpeg",
    "type": "Image",
    "url": "https://vernissage.instance/storage/2043486227r84b5366d52hfddc666149.png"
  },
  "id": "https://vernissage.instance/actors/johndoe",
  "image": {
    "mediaType": "image/jpeg",
    "type": "Image",
    "url": "https://vernissage.instance/storage/564a5c1de4014h2db859jc2be4627cb7.jpg"
  },
  "inbox": "https://vernissage.instance/actors/johndoe/inbox",
  "manuallyApprovesFollowers": false,
  "movedTo": "https://another.instance/actors/johndoe",
  "name": "John Doe",
  "outbox": "https://vernissage.instance/actors/johndoe/outbox",
  "preferredUsername": "johndoe",
  "publicKey": {
    "id": "https://vernissage.instance/actors/johndoe#main-key",
    "owner": "https://vernissage.instance/actors/johndoe",
    "publicKeyPem": "-----BEGIN PUBLIC KEY-----\nMIIBBAQEFAAO...NVy8d\n/wIDAQAB\n-----END PUBLIC KEY-----"
  },
  "published": "2023-07-01T06:19:36.378Z",
  "summary": "👨🏻‍💻 Software engineer (favorite technologies: #Swift/#dotNET/#Angular)",
  "tag": [
    {
      "href": "https://vernissage.instance/tags/dotNET",
      "name": "dotNET",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/tags/Swift",
      "name": "Swift",
      "type": "Hashtag"
    },
    {
      "href": "https://vernissage.instance/tags/Angular)",
      "name": "Angular)",
      "type": "Hashtag"
    }
  ],
  "type": "Person",
  "url": "https://vernissage.instance/@johndoe"
}
```

### Move to Vernissage

`Move to Vernissage` means the old account exists on a remote server, while the destination account is hosted on Vernissage.

Required actor state:
- the destination account on Vernissage must expose the old account in `alsoKnownAs` (for local accounts it is managed through local aliases).
- the source (old) account must expose `movedTo` pointing to the destination account.

Inbound processing in Vernissage:
1. Vernissage receives `Move` in actor/shared inbox and validates HTTP signature.
2. Vernissage validates semantic consistency:
   - `actor` and `object` must point to the same source account,
   - `target` must point to a different account than `actor`,
   - destination account must confirm alias relation (`alsoKnownAs`),
   - source account must already expose `movedTo == target`.
3. When validation passes, Vernissage migrates local followers in database:
   - local follows from `follower -> source` are moved to `follower -> target`,
   - follows to the old account are removed,
   - follow counters are recalculated.

Important follow behavior for moved accounts:
- if a `Follow` is sent to a local account with `movedTo` set, Vernissage returns HTTP `200` to the sender, does not create follow relation in database, and sends ActivityPub `Reject`.

### Move from Vernissage

`Move from Vernissage` means the source (old) account is local to Vernissage and points to a new destination account (local or remote).

Initiation:
1. User calls `POST /api/v1/users/:name/move` with password and target account.
2. Vernissage verifies password, resolves target actor, and validates alias relation (`target.alsoKnownAs` contains source).
3. Vernissage stores `movedTo` on source account.

Migration and federation:
1. Local followers are migrated in Vernissage database from source to target.
2. If target is remote, Vernissage sends `Follow` from local followers to target inboxes.
3. Vernissage sends ActivityPub `Move` to remote followers of the source account (`source -> target`), so remote platforms can continue migration on their side.

Unmove:
1. User can clear migration state using `POST /api/v1/users/:name/unmove`.
2. This clears `movedTo` on the local account.
3. Vernissage sends `Update(Person)` to remote servers (for synchronized profile state).
4. Vernissage does not send a dedicated rollback activity for previously sent `Move`.

## Reports (Flag)

Supported activities for reports (flags):

- `Flag` - report abusive content or user behavior between instances.

### Receiving reports from remote instances

1. Vernissage accepts incoming `Flag` activities in inbox/shared inbox processing and verifies HTTP signature.
2. `Flag` is processed only when it references a local target:
   - a local status (`object` contains local status id), or
   - a local user (`object` contains local actor id).
3. Vernissage creates a local `Report` entry with:
   - `isLocal = false` (remote-origin report),
   - `forward = false`,
   - `activityPubId` set to the `Flag` id (idempotency key).
4. If a report with the same `activityPubId` already exists, the activity is ignored as duplicate.
5. After successful save, moderators receive `adminReport` notifications.

### Sending reports to remote instances

1. Local report can be marked for federation (`forward = true`) via report create flow or moderator `send` action.
2. Sending is performed asynchronously by queue (`apFlag` / `FlagCreaterJob`).
3. Vernissage forwards only reports targeting remote users (`reportedUser.isLocal == false`).
4. Target inbox is resolved as `sharedInbox` (preferred) or `userInbox`.
5. Vernissage sends ActivityPub `Flag` signed by the local system actor (default system user), with:
   - `reportedActorId` set to the reported remote actor,
   - optional `reportedObjectIds` (when report references a status),
   - optional textual `content` (category/comment combined).

## Extensions

The Vernissage platform introduces additional fields to ActivityPub objects to enhance the experience
of publishing and consuming photographic content. These extensions are primarily intended for
applications focused on photography and visual media. The fields are added using custom context
definitions and are compatible with the ActivityStreams JSON-LD structure.

Base URI: [https://joinvernissage.org/ns#](https://joinvernissage.org/ns#)

Contains terms used for Vernissage features:
- [geonameId](https://joinvernissage.org/ns#geonameId) — geonameId property for GeoNames identifier.
- [exif](https://joinvernissage.org/ns#exif) — exif property for camera metadata.
- [Category](https://joinvernissage.org/ns#Category) — Category property for categorizing entity.

### FEP-EE3A (Exif metadata)

Vernissage currently supports both sending and receiving EXIF metadata in ActivityPub payloads, aligned with FEP-EE3A.

> Note: In one of the future Vernissage releases, support for sending EXIF using the legacy extension `https://joinvernissage.org/ns#exif` will be removed. Only FEP-EE3A compatible EXIF federation will remain.

Detailed FEP specification:
- [FEP-EE3A: Exif metadata federation](https://codeberg.org/fediverse/fep/src/branch/main/fep/ee3a/fep-ee3a.md)
