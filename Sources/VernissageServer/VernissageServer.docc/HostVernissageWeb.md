# Host Vernissage WEB

Application which is Web component for Vernissage photos sharing platform.

@Metadata {
    @PageImage(purpose: card, source: "host-web-card", alt: "The profile image for web documentation.")
}

## Prerequisites

Before you start Web client you have to run Vernissage API.
Here <doc:HostVernissageServer> you can find instructions how to do it on local development environment. 

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

## Getting started

After clonning the reposity you can easly run the Web client. Go to main repository folder and run the command:

```bash
$ ng serve
```

Navigate to [http://localhost:4200/](http://localhost:4200/). The application will automatically
reload if you change any of the source files.

## Docker

In production environments, it is best to use a [docker image](https://hub.docker.com/repository/docker/mczachurski/vernissage-web).
