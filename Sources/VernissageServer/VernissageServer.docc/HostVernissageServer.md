# Host Vernissage API

Application which is main API component for Vernissage photos sharing platform.

@Metadata {
    @PageImage(purpose: card, source: "host-server-card", alt: "The profile image for server documentation.")
}

## Overview

Vernissage API server is created in [Swift](https://www.swift.org/) language with [Vapor](https://vapor.codes) framework.
We can run it in all operating systems supporting `Swift` and `Vapor`.

## Prerequisites

Install the `GD` library on your computer. If you're using macOS, install Homebrew then run the command `brew install gd`.
If you're using Linux, run `apt-get libgd-dev` as root.

## Architecture

```
    +------------- +                           +------------- +
    |   Client A   |-------------+-------------|   Client B   |
    +--------------+             |             +------------- +
                                 |
                                 |
                   +-----------------------------+
                   |   VernissageAPI (Swift)     |
                   +-------------+---------------+
                                 |
             +-------------------+-------------------+
             |                   |                   |
    +--------+--------+   +------+------+   +--------+-----------+
    |   PostgreSQL    |   |    Redis    |   |  ObjectStorage S3  |
    +-----------------+   +-------------+   +--------------------+
```

## Getting started

After clonning the reposity you can easly run the API. Go to main repository folder and run the command:

```bash
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
    "refreshToken": "U8zMqw1tGHqIk0cUXmvAEcwYIpsQlwWUxHa0fnXbu"
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
 
In production environment you can override configuration parameters by environment variables. For example if you want to set custom `baseAddress` you have to define variable: `VERNISSAGE_BASEADDRESS`, etc.

## Docker

In production environments, it is best to use a [docker image](https://hub.docker.com/repository/docker/mczachurski/vernissage-server).