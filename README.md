# Vernissage Server

[![Build Server](https://github.com/VernissageApp/VernissageServer/actions/workflows/build.yml/badge.svg)](https://github.com/VernissageApp/VernissageServer/actions/workflows/build.yml)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg?style=flat)](https://developer.apple.com/swift/)
[![Vapor 4](https://img.shields.io/badge/Vapor-4-blue.svg?style=flat)](https://vapor.codes)
[![Platforms macOS | Linux](https://img.shields.io/badge/Platforms-macOS%20%7C%20Linux-lightgray.svg?style=flat)](https://developer.apple.com/swift/)
[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-mczachurski%2Fvernissage--server-2496ED?style=flat)](https://hub.docker.com/r/mczachurski/vernissage-server)

API server for **Vernissage**, written in Swift and built with Vapor. Vernissage is a federated, photo-first social platform connected to the fediverse through **ActivityPub**.

This repository is the backend for the Vernissage ecosystem. It handles authentication, timelines, statuses, media processing, moderation, instance settings, federation, queues, and scheduled jobs for the mobile and web clients.

## Highlights

- Swift 6.2 backend built on Vapor 4
- SQLite for local development, PostgreSQL for production deployments
- Redis-backed queues and scheduled jobs, with optional in-process workers
- S3-compatible object storage support for media files
- ActivityPub federation with WebFinger, HTTP Signatures, and NodeInfo
- Automatic migrations and seed data, including a default administrator account
- DocC-based API and hosting documentation

## Quick Links

- Documentation: [docs.joinvernissage.org](https://docs.joinvernissage.org/)
- API documentation: [docs.joinvernissage.org/documentation/vernissageserver](https://docs.joinvernissage.org/documentation/vernissageserver)
- Federation notes: [FEDERATION.md](FEDERATION.md)
- Mobile client: [VernissageMobile](https://github.com/VernissageApp/VernissageMobile)
- Web client: [VernissageWeb](https://github.com/VernissageApp/VernissageWeb)
- Project website: [joinvernissage.org](https://joinvernissage.org)

## Architecture

Vernissage Server is organized around a conventional backend split:

- `Controllers` expose HTTP and ActivityPub endpoints.
- `Services` contain domain logic for accounts, timelines, statuses, federation, storage, notifications, and search.
- `Models`, `DTOs`, and `Migrations` define persistence and the public API contract.
- `QueueJobs` and `ScheduledJobs` handle asynchronous and recurring work.
- `ActivityPubKit` contains reusable federation-specific code.

At runtime, the API sits between client applications and the infrastructure it depends on:

- clients: Vernissage Mobile, Vernissage Web, external OAuth clients, federated servers,
- persistence: SQLite or PostgreSQL via Fluent,
- async infrastructure: Redis queues and schedulers,
- media layer: local storage for development or S3-compatible object storage in real deployments.

The application startup sequence is worth understanding: on startup it loads configuration, registers routes, configures the database, runs migrations, seeds dictionaries and the default admin user, initializes cached settings, then enables middleware, queues, schedulers, email, and storage.

## Requirements

- Swift 6.2
- macOS 15+ or a modern Linux distribution supported by Swift
- system libraries for image and EXIF processing:
  - `gd`
  - `libexif`
  - `libiptcdata`
- optional for fuller setups:
  - PostgreSQL
  - Redis
  - S3-compatible storage such as AWS S3 or MinIO

### macOS

```bash
$ brew install gd libexif libiptcdata
```

### Linux

```bash
$ apt install -y libgd-dev libexif-dev libiptcdata0-dev
```

## Getting Started

For local development, the default configuration is intentionally simple:

- the app reads `appsettings.json`,
- it creates or uses a local SQLite database file,
- migrations and seed data run automatically,
- a default `admin` user is created with password `admin`.

Run the server from the repository root:

```bash
$ swift run
```

By default, the API starts on `http://localhost:8080`.

Useful first checks:

- root: `GET /`
- health: `GET /api/v1/health`

### Example Login

```bash
$ curl --location 'http://localhost:8080/api/v1/account/login' \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data-raw '{
    "userNameOrEmail": "admin",
    "password": "admin"
  }'
```

Example response:

```json
{
  "accessToken": "<jwt>",
  "refreshToken": "<refresh-token>",
  "xsrfToken": "<xsrf-token>",
  "expirationDate": "<iso-8601-date>",
  "userPayload": {
    "userName": "admin"
  }
}
```

Use `Authorization: Bearer <accessToken>` for authenticated requests.

If authentication is based on cookies, state-changing endpoints also require XSRF protection via the `X-XSRF-TOKEN` header. When the access token is sent in the `Authorization: Bearer` header, the extra XSRF header is not required.

## Configuration

Configuration is loaded in this order:

1. `appsettings.json`
2. `appsettings.<environment>.json`
3. `appsettings.local.json`
4. environment variables

For local overrides, create `appsettings.local.json` next to `appsettings.json`:

```json
{
  "vernissage": {
    "baseAddress": "http://localhost:8080",
    "connectionString": "postgres://postgres:secretpass@localhost:5432/postgres",
    "queueUrl": "redis://127.0.0.1:6379",
    "s3Address": "https://s3.eu-central-1.amazonaws.com",
    "s3Region": "eu-central-1",
    "s3Bucket": "your-bucket-test",
    "s3AccessKeyId": "YOUR_ACCESS_KEY",
    "s3SecretAccessKey": "YOUR_SECRET_KEY",
    "s3Http1OnlyMode": "false",
    "disableQueueJobs": "false",
    "disableScheduledJobs": "false"
  }
}
```

Most important keys:

| Key | Purpose |
| --- | --- |
| `baseAddress` | Public base URL of the instance. Important for federation and links. |
| `connectionString` | SQLite file path or PostgreSQL connection string. |
| `queueUrl` | Redis connection string used for queues and cache. |
| `s3Address` | Base URL of S3-compatible storage. |
| `s3Region` | AWS region. When set, AWS S3 settings take precedence over custom S3 address handling. |
| `s3Bucket` | Bucket name for uploaded media. |
| `s3AccessKeyId` / `s3SecretAccessKey` | Credentials for object storage. |
| `s3Http1OnlyMode` | Forces HTTP/1 mode for S3 client integrations when needed. |
| `disableQueueJobs` | Disables in-process queue workers. |
| `disableScheduledJobs` | Disables in-process schedulers. |

In production, configuration can be overridden with environment variables such as `VERNISSAGE_BASEADDRESS`, `VERNISSAGE_CONNECTIONSTRING`, `VERNISSAGE_QUEUEURL`, and related `VERNISSAGE_*` keys.

The application also supports standard Vapor runtime configuration:

- Vapor runs in the `development` environment by default, which is the mode used when starting locally with `swift run`.
- The Docker image starts the server with `serve --env production`, so containers run in the `production` environment by default.
- You can change the environment explicitly with `--env`, for example `swift run VernissageServer serve --env production`.
- You can override the log level with Vapor's `--log` flag or the `LOG_LEVEL` environment variable.

Supported log levels are: `trace`, `debug`, `info`, `notice`, `warning`, `error`, and `critical`.

Vapor defaults to `info` logging in `development` and `notice` in `production`, unless you override it.

## Storage, Queues, and Scheduled Jobs

The server runs in several modes depending on configuration:

- without `queueUrl`, Redis-backed jobs are disabled and the app falls back to a no-op queue driver,
- with `queueUrl`, Redis is used for queues and cache,
- with `disableQueueJobs=false`, workers can run in the same process,
- with `disableScheduledJobs=false`, recurring jobs also run in-process.

Examples of background work handled by the server:

- email delivery,
- web push notifications,
- ActivityPub inbox and outbox processing,
- status creation and federation side effects,
- import tasks,
- archive generation and cleanup,
- trending calculations,
- cleanup of temporary files, captchas, failed logins, and stale statuses.

For media storage, local files are enough for development, but S3-compatible storage is the expected setup for real deployments.

## Federation

Vernissage Server is a federated backend, not only a private API.

Supported protocols and standards:

- [ActivityPub](https://www.w3.org/TR/activitypub/) server-to-server
- [WebFinger](https://webfinger.net/)
- [HTTP Signatures](https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures)
- [NodeInfo](https://nodeinfo.diaspora.software/)

Important public endpoints include:

- `/.well-known/webfinger`
- `/.well-known/nodeinfo`
- `/.well-known/host-meta`
- `/api/v1/nodeinfo/2.0`
- `/shared/inbox`

See [FEDERATION.md](FEDERATION.md) for the supported extensions and more precise federation notes.

## Repository Layout

- `Sources/VernissageServer` - main application target
- `Sources/VernissageServer/Controllers` - HTTP and ActivityPub endpoints
- `Sources/VernissageServer/Services` - business logic
- `Sources/VernissageServer/Models` - Fluent models
- `Sources/VernissageServer/Migrations` - database migrations
- `Sources/VernissageServer/QueueJobs` - asynchronous jobs
- `Sources/VernissageServer/ScheduledJobs` - recurring jobs
- `Sources/VernissageServer/VernissageServer.docc` - DocC documentation
- `Sources/ActivityPubKit` - reusable ActivityPub support code
- `Tests` - unit tests
- `TestRequests` - request samples useful during manual API testing
- `Public` and `Resources` - static and bundled resources used by the server

## Development

Build the project:

```bash
$ swift build
```

Run tests:

```bash
$ swift test --no-parallel
```

Preview the local DocC documentation:

```bash
$ swift package --disable-sandbox preview-documentation \
  --exclude-extended-types \
  --product VernissageServer
```

Generate static documentation output:

```bash
$ swift package --allow-writing-to-directory .build/docs \
  generate-documentation --target VernissageServer \
  --disable-indexing \
  --exclude-extended-types \
  --transform-for-static-hosting \
  --output-path .build/docs
```

Developer notes:

- object IDs are Snowflake-like `bigint` values, but the JSON API exposes them as strings,
- startup runs migrations and seeders automatically,
- many authenticated write endpoints are protected by both auth and XSRF validation,
- logs go to stdout, which keeps local development and containerized deployments simple.

## Docker

The repository includes a `Dockerfile` and a minimal `docker-compose.yml` for running the API in a production-like environment.

Build and start locally with Docker:

```bash
$ docker compose build
$ docker compose up app
```

You can also build and run the `Dockerfile` directly, without `docker compose`:

```bash
$ docker build -t vernissage-server .
$ docker run --rm -p 8080:8080 vernissage-server
```

To pass custom configuration, provide standard `VERNISSAGE_*` environment variables when starting the container:

```bash
$ docker run --rm -p 8080:8080 \
  -e VERNISSAGE_BASEADDRESS=http://localhost:8080 \
  -e VERNISSAGE_CONNECTIONSTRING=postgres://postgres:secretpass@host.docker.internal:5432/postgres \
  -e VERNISSAGE_QUEUEURL=redis://host.docker.internal:6379 \
  vernissage-server
```

The image entrypoint starts the server in the `production` environment and listens on port `8080`.

Production images are published to [Docker Hub](https://hub.docker.com/r/mczachurski/vernissage-server).

For a fuller deployment, including proxy, web client, push service, and Redis, refer to the DocC hosting guides at [docs.joinvernissage.org](https://docs.joinvernissage.org/).

## Security

If you find a security issue, please use [GitHub Security Advisories](https://github.com/VernissageApp/VernissageServer/security/advisories/new) or contact <info@vernissage.photos>.

See [SECURITY.md](SECURITY.md) for the disclosure policy.

## License

This project is licensed under the [Apache License 2.0](LICENSE).
