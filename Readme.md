# Vernissage API server

![Build Status](https://github.com/VernissageApp/VernissageServer/workflows/Build/badge.svg)
[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange.svg?style=flat)](ttps://developer.apple.com/swift/)
[![Vapor 4](https://img.shields.io/badge/vapor-4.0-blue.svg?style=flat)](https://vapor.codes)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![Platforms macOS | Linux](https://img.shields.io/badge/Platforms-macOS%20%7C%20Linux%20-lightgray.svg?style=flat)](https://developer.apple.com/swift/)

Application which is main API component for Vernissage photos sharing platform.

## Prerequisites

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
$ apt install -y libgd-dev libexif-dev libiptcdata0-dev
```

## Architecture

```
               +-----------------------------+
               |   VernissageWeb (Angular)   |
               +-------------+---------------+
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

API description you can find in `Docs` folder or here: [https://api.vernissage.photos](https://api.vernissage.photos/).

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
 - `s3*` - configuration of S3 storage. Here you can use any external S3 compatible cloud storage or [minio](https://min.io) docker ([https://hub.docker.com/r/minio/minio](https://hub.docker.com/r/minio/minio)).
 
> [!NOTE]
> If the `s3Region` variable is set, it causes the other settings to be overwritten and use Amazon AWS S3.
 
In production environment you can override configuration parameters by environment variables. For example if you want to set custom `baseAddress` you have to define variable: `VERNISSAGE_BASEADDRESS`, etc.

## Docker

In production environments, it is best to use a [docker image](https://hub.docker.com/repository/docker/mczachurski/vernissage-server).
