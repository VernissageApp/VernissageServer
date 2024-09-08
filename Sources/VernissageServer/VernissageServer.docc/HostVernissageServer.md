# Host Vernissage Server (API)

Application which is main API component for Vernissage photos sharing platform.

@Metadata {
    @PageImage(purpose: card, source: "host-server-card", alt: "The profile image for server documentation.")
}

## Overview

Vernissage API server is created in [Swift](https://www.swift.org/) language with [Vapor](https://vapor.codes) framework.
We can run it in all operating systems supporting `Swift` and `Vapor`.

## Prerequisites

Running the application requires installing [Swift](https://www.swift.org/install/).

Three libraries are required to build/run the Vernissage API application: [GD](https://github.com/libgd/libgd), [libexif](https://github.com/libexif/libexif) and [libiptcdata](https://libiptcdata.sourceforge.net).
These libraries are responsible mostly for image manipulation (resizing, converting, exif metadata, etc.).

### macOs

Using [Homebrew](https://brew.sh) you need to run following command:

```bash
$ brew install gd libexif libiptcdata
```

### Linux

If you're using Linux you need to run following command as root.

```bash
$ apt install -y libgd-dev libiptc-data libexif-dev libiptcdata0-dev
```

## Getting started

Below are all the commands necessary to run the API part of the Vernissage.

```bash
$ git clone https://github.com/VernissageApp/VernissageServer.git
$ cd VernissageServer
$ swift run
```

API should start. Configuration will be read from `appsettings.json` file. SQLite database will be used. You can sign in using default `admin` account (with password: `admin`). For example:

```bash
$ curl --location 'http://localhost:8080/api/v1/account/login' \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--data-raw '{
    "userNameOrEmail": "admin",
    "password": "admin"
}'
```

Request will return JSON:

```json
{
    "accessToken": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzUxMiJ9.eyJpZCI6IjcyNTA3Mjk3NzcyNjEyMzYyMjUiLCJhcHBsaWNhdGlvbiI6IlZlcm5pc3NhZ2UgMS4wLjAtYWxwaGExIiwicm9sZXMiOlsiYWRtaW5pc3RyYXRvciJdLCJ1c2VyTmFtZSI6ImFkbWluIiwibmFtZSI6IkFkbWluaXN0cmF0b3IiLCJlbWFpbCI6ImFkbWluQGxvY2FsaG9zdCIsImV4cCI6MTcwNjE2OTE1Mi4zODk5NTMxfQ.Z87v9HvfBM6fn6F8fu06ToPShT9F55G74wL676SLmSdLMzyz3ykfsmS-GDNIqfUatfwdBvSxQgpjUO6IzYAuQKZ925tdN8DwN6kVAEa2mJLlntc66qAkQSiPeXYEl29Cgbg6TuAvxghWVO5PVliMG8mxO7uwSFDN095mNxbee8x8P-ogL176vXBhJ_rWcm1fY7_n-qSn6XN2GbgjiywnOZfvHNNtLvbikcpJeIAzHH-BlXolWsUauuZGZBeFv5TuBr13r5PZfVar0FH9Uwj39w5DV3jxlwRPyejux4LL96dvrEsP4Btx88c3SSLyxm1REfRR_wKoUoXK8iVqfBU6TQ",
    "refreshToken": "U8zMqw1tGHqIk0cUXmvAEcwYIpsQlwWUxHa0fnXbu",
    "xsrfToken": "OpjXDt6VwT0HNrLWPhcp4yXqAhdhngWS2i1Ilt0v0dNdBpLkhU24XGT4dj4W3EJES"
}
```

After successfully sign in you can use other endpoints (with `Authentication: Bearer` header).

## Custom configuration

In local development environment you can create `appsettings.local.json` file (near `appsettings.json` file). This file can look like that:

```json
{
    "vernissage": {
        "baseAddress": "http://localhost:8080",
        "connectionString": "postgres://postgres:secretpass@localhost:5432/postgres",
        "queueUrl": "redis://127.0.0.1:6379",
        "s3Address": "https://s3.eu-central-1.amazonaws.com",
        "s3Region": "eu-central-1",
        "s3Bucket": "your-bucket-test",
        "s3AccessKeyId": "ASDA8AS8HSDSU",
        "s3SecretAccessKey": "DSfEaBUYIhoouHhigygGtldDpLesmXCz10ICe0F"
    }
}
```

Here you can configure three external resources:

 - `connectionString` - you can use SQLite or Postgres database connection string
 - `queueUrl` - URL to Redis in memory data store (used as cache and queue by Vernissage)
 - `s3*` - configuration of S3 storage. Here you can use any external S3 compatible cloud storage or [minio](https://min.io) docker ([https://hub.docker.com/r/minio/minio](https://hub.docker.com/r/minio/minio))

> Note: If the `s3Region` variable is set, it causes the other settings to be overwritten and use Amazon AWS S3.

In production environment you can override configuration parameters by environment variables. For example if you want to set custom `baseAddress` you have to define variable: `VERNISSAGE_BASEADDRESS`, etc.

## File logger

By default, the system displays logs only on the system console. If logging is also to be done to a file we need to set a system environment variable:

- `VERNISSAGE_LOG_PATH` - file path e.g.: `logs/vernissage.log`.

We can also set the default login level by setting a system environment variable:

- `LOG_LEVEL` - more information about log levels you can find [here](https://docs.vapor.codes/basics/logging/).

## Sentry

It is possible to send application errors to the Sentry central logging system. To do this, set appropriate environment variables:

- `SENTRY_DSN` - for writing Vernissage Server (API) logs
- `SENTRY_DSN_WEB` - for writing Vernissage Web logs

## Docker

In production environments, it is best to use a [docker image](https://hub.docker.com/repository/docker/mczachurski/vernissage-server).
