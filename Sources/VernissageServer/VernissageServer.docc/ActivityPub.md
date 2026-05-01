# ActivityPub

A decentralized social networking protocol based upon the ActivityStreams 2.0 data format and JSON-LD.

- [Discovery and security](#Discovery-and-security)
- [Status federation](#Status-federation)
- [Profile federation](#Profile-federation)
- [Reports (Flag) federation](#Reports-Flag-federation)
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
- `Update` - updates existing status in database.
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
- `tag.type` - either `Mention`, `Hashtag`, or `Emoji` is currently supported.
- `tag.name` - the plain-text Webfinger address of a profile `Mention` (@user or @user@domain), or the plain-text `Hashtag` (#tag), or the custom `Emoji` shortcode (:thounking:).
- `tag.href` - URL of the actor or tag.
- `tag.icon` - information about emoji icon (`NoteTagIconDto` object).
- `tag.updated` - date when emoji has been updated.
- `tag.icon.type` - type of icon (`Image` is supported only).
- `tag.icon.mediaType` - mime type of icon.
- `tag.icon.url` - URL to icon file.
- `attachment.url` - URL used to fetch media attachment.
- `attachment.name` - media description (ALT text).
- `attachment.mediaType` - used to distinguish if attachment is an image.
- `attachment.blurhash` - blurred preview hash (see: https://docs.joinmastodon.org/spec/activitypub/#blurhash).
- `attachment.exifData` - metadata information about the image (collection of `PropertyValue`, compatible with FEP-EE3A).
- `attachment.exif` - legacy metadata extension (see: https://joinvernissage.org/ns#exif), maintained for backward compatibility.
- `attachment.location` - extension from https://schema.org (type `Place`).
- `attachment.location.geonameId` - additional extension to location (see: https://joinvernissage.org/ns#geonameId).

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

### Create

`Create` is used to publish a new remote status (`Note`) and deliver it to followers.

#### Schema

Used properties:
- `id` - unique id of the `Create` activity.
- `type` - must be `Create`.
- `actor` - actor who publishes the status.
- `to`/`cc` - audience of the created status.
- `object` - created status object (usually `Note`; see full status schema above).

#### JSON+LD Example

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://remote.instance/users/johndoe/statuses/7500892058677152209/activity",
  "type": "Create",
  "actor": "https://remote.instance/users/johndoe",
  "to": "https://www.w3.org/ns/activitystreams#Public",
  "object": {
      // Status JSON.
  }
}
```

### Update

`Update` is used to publish edits to an already federated remote status (`Note`).

#### Schema

Used properties:
- `id` - unique id of the `Update` activity.
- `type` - must be `Update`.
- `actor` - actor who updates the status.
- `to`/`cc` - audience of the updated status.
- `object` - updated status object (usually `Note`; see full status schema above).
- `object.id` - id of the existing status being updated.

#### JSON+LD Example

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://remote.instance/users/johndoe/statuses/7500892058677152209#updates/2",
  "type": "Update",
  "actor": "https://remote.instance/users/johndoe",
  "to": "https://www.w3.org/ns/activitystreams#Public",
  "object": {
      // Status JSON.
  }
}
```

### Delete

`Delete` is used to remove a previously federated status from remote instances.

#### Schema

Used properties:
- `id` - unique id of the `Delete` activity.
- `type` - must be `Delete`.
- `actor` - actor that owns the deleted status.
- `object` - identifier (or tombstone object) of the status to delete.

#### JSON+LD Example

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://remote.instance/users/johndoe#delete-7500892058677152209",
  "type": "Delete",
  "actor": "https://remote.instance/users/johndoe",
  "object": {
    "id": "https://remote.instance/users/johndoe/statuses/7500892058677152209",
    "type": "Note"
  }
}
```

### Like

`Like` is used to mark a remote status as a favourite.

#### Schema

Used properties:
- `id` - unique id of the `Like` activity.
- `type` - must be `Like`.
- `actor` - actor who likes the status.
- `object` - id of the liked status.

#### JSON+LD Example

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://remote.instance/users/johndoe#likes/7333524055101671425",
  "type": "Like",
  "actor": "https://remote.instance/users/johndoe",
  "object": "https://vernissage.instance/@alice/7333524055101671425"
}
```

### Announce

`Announce` is used to boost/reblog a remote status.

#### Schema

Used properties:
- `id` - unique id of the `Announce` activity.
- `type` - must be `Announce`.
- `actor` - actor who boosts the status.
- `object` - id of the boosted status.
- `to`/`cc` - audience for boost delivery.

#### JSON+LD Example

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://remote.instance/users/johndoe#announces/7333524055101671425",
  "type": "Announce",
  "actor": "https://remote.instance/users/johndoe",
  "object": "https://vernissage.instance/@alice/7333524055101671425",
  "to": "https://www.w3.org/ns/activitystreams#Public"
}
```

### Undo

`Undo` is used to revert a previous interaction, mainly `Like` or `Announce` for statuses.

#### Schema

Used properties:
- `id` - unique id of the `Undo` activity.
- `type` - must be `Undo`.
- `actor` - actor reverting the action.
- `object` - embedded activity being reverted (`Like` or `Announce` with its target status id).
- `object.id` - unique id of the embedded activity object (`Like`/`Announce`).

#### JSON+LD Example

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://remote.instance/users/johndoe#undo/7333524055101671425",
  "type": "Undo",
  "actor": "https://remote.instance/users/johndoe",
  "object": {
    "id": "https://remote.instance/users/johndoe#likes/7333524055101671425",
    "type": "Like",
    "actor": "https://remote.instance/users/johndoe",
    "object": "https://vernissage.instance/@alice/7333524055101671425"
  }
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
- `publicKey.id` - public key identifier.
- `publicKey.owner` - URL to the public key owner.
- `publicKey.publicKeyPem` - public key PEM.
- `attachment.type` - only `PropertyValue` extension from https://schema.org is supported.
- `attachment.name` - profile field name.
- `attachment.value` - profile field value.
- `tag.name` - plain-text `Hashtag` (#tag), or custom `Emoji` shortcode (:thounking:).
- `tag.href` - URL of the tag.
- `tag.icon` - information about emoji icon (`PersonImageDto` object).
- `tag.icon.type` - type of icon (`Image` is supported only).
- `tag.icon.mediaType` - mime type of icon.
- `tag.icon.url` - URL to icon file.

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

### Follow

`Follow` is used to subscribe to profile updates from another actor.

#### Schema

Used properties:
- `id` - unique id of the `Follow` activity.
- `type` - must be `Follow`.
- `actor` - actor that requests following.
- `object` - target actor id that should be followed.

#### JSON+LD Example

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://remote.instance/users/alice#follow/7333615812782637057",
  "type": "Follow",
  "actor": "https://remote.instance/users/alice",
  "object": "https://vernissage.instance/actors/johndoe"
}
```

### Accept

`Accept` is used to approve a previously received `Follow` request.

#### Schema

Used properties:
- `id` - unique id of the `Accept` activity.
- `type` - must be `Accept`.
- `actor` - actor that accepts the follow request.
- `object` - embedded `Follow` activity that is being approved.
- `object.type` - must be `Follow`.
- `object.object` - target actor id of the accepted follow.

#### JSON+LD Example

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://vernissage.instance/actors/johndoe#accept/follow/7333615812782637057",
  "type": "Accept",
  "actor": "https://vernissage.instance/actors/johndoe",
  "object": {
    "id": "https://remote.instance/users/alice#follow/7333615812782637057",
    "type": "Follow",
    "actor": "https://remote.instance/users/alice",
    "object": "https://vernissage.instance/actors/johndoe"
  }
}
```

### Reject

`Reject` is used to deny a previously received `Follow` request.

#### Schema

Used properties:
- `id` - unique id of the `Reject` activity.
- `type` - must be `Reject`.
- `actor` - actor that rejects the follow request.
- `object` - embedded `Follow` activity that is being rejected.
- `object.type` - must be `Follow`.
- `object.object` - target actor id of the rejected follow.

#### JSON+LD Example

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://vernissage.instance/actors/johndoe#reject/follow/7333615812782637057",
  "type": "Reject",
  "actor": "https://vernissage.instance/actors/johndoe",
  "object": {
    "id": "https://remote.instance/users/alice#follow/7333615812782637057",
    "type": "Follow",
    "actor": "https://remote.instance/users/alice",
    "object": "https://vernissage.instance/actors/johndoe"
  }
}
```

### Update

`Update` is used to broadcast profile changes (display name, bio, avatar/header, fields, migration flags).

#### Schema

Used properties:
- `id` - unique id of the `Update` activity.
- `type` - must be `Update`.
- `actor` - actor whose profile is being updated.
- `to`/`cc` - audience for profile update delivery.
- `object` - updated profile object (`Person`/`Service`).
- `object.type` - actor object type (`Person` or `Service`).

#### JSON+LD Example

```jsonc
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://vernissage.instance/actors/johndoe#updates/7500892058677152209",
  "type": "Update",
  "actor": "https://vernissage.instance/actors/johndoe",
  "to": "https://www.w3.org/ns/activitystreams#Public",
  "cc": "https://vernissage.instance/actors/johndoe/followers",
  "object": {
      // Profile JSON
  }
}
```

### Delete

`Delete` is used to remove a profile from remote instances.

#### Schema

Used properties:
- `id` - unique id of the `Delete` activity.
- `type` - must be `Delete`.
- `actor` - actor being deleted.
- `object` - actor id of the removed profile.

#### JSON+LD Example

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://remote.instance/users/alice#delete",
  "type": "Delete",
  "actor": "https://remote.instance/users/alice",
  "to": "https://www.w3.org/ns/activitystreams#Public",
  "object": "https://remote.instance/users/alice"
}
```

### Undo

`Undo` is used to revert a previous `Follow` (unfollow profile).

#### Schema

Used properties:
- `id` - unique id of the `Undo` activity.
- `type` - must be `Undo`.
- `actor` - actor that reverts the follow.
- `object` - embedded `Follow` activity being reverted.
- `object.type` - must be `Follow`.
- `object.actor` - source actor from the original follow.
- `object.object` - target actor from the original follow.

#### JSON+LD Example

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://remote.instance/users/alice#follow/7333615812782637057/undo",
  "type": "Undo",
  "actor": "https://remote.instance/users/alice",
  "object": {
    "id": "https://remote.instance/users/alice#follow/7333615812782637057",
    "type": "Follow",
    "actor": "https://remote.instance/users/alice",
    "object": "https://vernissage.instance/actors/johndoe"
  }
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

#### Schema

Used properties:
- `@context` - ActivityStreams context.
- `id` - unique id of the `Move` activity.
- `type` - must be `Move`.
- `actor` - source actor (old account).
- `object` - source actor (same account as `actor`).
- `target` - destination actor (new account).
- `to` - audience for migration activity (usually source followers collection).

#### JSON+LD Example

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://vernissage.instance/actors/johndoe#move/7500892058677152209",
  "type": "Move",
  "actor": "https://vernissage.instance/actors/johndoe",
  "object": "https://vernissage.instance/actors/johndoe",
  "target": "https://another.instance/actors/johndoe",
  "to": "https://vernissage.instance/actors/johndoe/followers"
}
```

Unmove:
1. User can clear migration state using `POST /api/v1/users/:name/unmove`.
2. This clears `movedTo` on the local account.
3. Vernissage sends `Update(Person)` to remote servers (for synchronized profile state).
4. Vernissage does not send a dedicated rollback activity for previously sent `Move`.

## Reports (Flag) federation

Supported activities for reports (flags):

- `Flag` - report abusive content or user behavior between instances.

### Schema

Used properties:
- `@context` - ActivityStreams context.
- `id` - unique id of the `Flag` activity.
- `type` - must be `Flag`.
- `actor` - actor that submits the report.
- `object` - reported object(s): actor id and optionally status/object ids.
- `to` - reported actor id (the moderation destination actor on the remote side).
- `content` - optional free-text explanation for moderators.

### JSON+LD Example

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://mastodon.example/ccb4f39a-506a-490e-9a8c-71831c7713a4",
  "type": "Flag",
  "actor": "https://mastodon.example/actor",
  "content": "Please review this account and its posts.",
  "object": [
    "https://example.com/users/1",
    "https://example.com/posts/380590",
    "https://example.com/posts/380591"
  ],
  "to": "https://example.com/users/1"
}
```

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
