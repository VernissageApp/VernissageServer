# Host Vernissage WEB

Application which is Web component for Vernissage photos sharing platform.

@Metadata {
    @PageImage(purpose: card, source: "host-web-card", alt: "The profile image for web documentation.")
}

## Prerequisites

Before you start Web client you have to run Vernissage API.
Here <doc:HostVernissageServer> you can find instructions how to do it on local development environment. 

Running the application requires installing [NodeJS](https://nodejs.org/en/download).

## Getting started

Below are all the commands necessary to run the Web part of the Vernissage.

```bash
$ git clone https://github.com/VernissageApp/VernissageWeb.git
$ cd VernissageWeb
$ npm install
$ ng serve
```

Navigate to [http://localhost:4200/](http://localhost:4200/). The application will automatically
reload if you change any of the source files.

## Docker

In production environments, it is best to use a [docker image](https://hub.docker.com/repository/docker/mczachurski/vernissage-web).

## Enable security headers

It is recommended to include secure headers in responses on production environments. This can be achieved by setting the system variable: `VERNISSAGE_CSP_IMG`. For example:

```bash
export VERNISSAGE_CSP_IMG=https://s3.eu-central-1.amazonaws.com
```

The value of the variable should point to the server address from which images served in the application are to be retrieved. This address will be added to the `Content-Security-Policy` header.
