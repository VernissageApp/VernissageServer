# Vernissage API server

![Build Status](https://github.com/VernissageApp/VernissageServer/workflows/Build/badge.svg)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat)](ttps://developer.apple.com/swift/)
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
