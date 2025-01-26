# Hosting Vernissage in Docker containers

This documentation describes how to run Vernissage in your custom Docker container hosting provider using `docker compose` on a Debian based system. 

The configuration consists of a *docker-compose.yml* and a *.env* file. 

## Installation

### docker compose

First install docker and docker compose:
```
apt update
apt install docker.io docker-compose-v2
```
Package names may vary, please refer to the documentation of your distribution.

### HOME

Then create an empty directory of your choosing, e.g. `/opt/vernissage`. This directory is the home of your deployment and holds both the configuration files described below. This document will use the name **HOME** to refer to this directory.

### docker-compose.yml

This docker compose configuration sets up all Vernissage containers for a Debian based deployment. It uses environment variables defined in *.env*. Please see *.env* below.

In a standard deployment no changes to this docker compose configuration are necessary.

Also included is a standard `redis-server` container. Beyond that PostgreSQL database and S3 storage are needed, which are not part of  this docker compose configuration.

Copy all of the following to **HOME**`/docker-compose.yml`:
```
services:
  api:
    image: mczachurski/vernissage-server:${DOCKER_TAG:-latest}
    restart: always
    healthcheck:
      test: curl --output /dev/null --silent --head --fail http://host.docker.internal:8080
      interval: 5s
    env_file: ".env"
    logging: &log-syslog
      driver: syslog
      options:
        tag: "{{.Name}}"
    depends_on:
      redis:
        condition: service_healthy
    networks:
      ip6net:
        aliases:
          - vernissage-api.internal
          - host.docker.internal

  web:
    image: mczachurski/vernissage-web:${DOCKER_TAG:-latest}
    restart: always
    env_file: ".env"
    depends_on:
      api:
        condition: service_started
    logging: *log-syslog
    networks:
      ip6net:
        aliases:
          - vernissage-web.internal
          - host.docker.internal

  proxy:
    image: mczachurski/vernissage-proxy:${DOCKER_TAG:-latest}
    restart: always
    ports:
      - "${EXPOSED_PORT:-8080}:8080"
    logging: *log-syslog
    depends_on:
      web:
        condition: service_started
    networks:
      ip6net:
        aliases:
          - vernissage-proxy.internal
          - host.docker.internal

  push:
    image: mczachurski/vernissage-push:${DOCKER_TAG:-latest}
    restart: always
    healthcheck: 
      test: curl --output /dev/null --silent --head --fail http://host.docker.internal:3000
      interval: 5s
    env_file: ".env"
    logging: *log-syslog
    depends_on:
      api:
        condition: service_started
    networks:
      ip6net:
        aliases:
          - vernissage-push.internal
          - host.docker.internal
    
  redis:
    image: redis
    restart: always
    healthcheck:
      test: redis-cli ping | grep PONG
      interval: 1s
      timeout: 3s
      retries: 5
    command: redis-server
    logging: *log-syslog
    networks:
      ip6net:
        aliases:
          - vernissage-redis.internal
          - host.docker.internal

networks:
   ip6net:
     enable_ipv6: true
     ipam:
       config:
         - subnet: ${IPV6_SUBNET:-2001:db8::/64}
```

### .env

This is the environment configuration for Vernissage. 

The passwords below are examples. Please do not adopt these in your installation, but generate your own.

Copy all of the following to **HOME**`/.env`:
```
########################################################################
# SERVER

# the address under which your Vernissage server is accessible on the internet
VERNISSAGE_BASEADDRESS=https://vernissage.example.com

# connection string to your postgres database
# in the format postgres://user:password@host:port/database
# if omited Vernissage creates a local sqlite database (not recommended)
VERNISSAGE_CONNECTIONSTRING=postgres://vernissage-user:P4s5w0rdXaXi93EJF1XaBH8b7yhLQMm7nBzfozh@host:5432/vernissage-db

# api url to your S3 storage
# if omited Vernissage uses a local storage directory (not recommended)
VERNISSAGE_S3ADDRESS=https://minio.example.com

# region of your S3 bucket in Amazon AWS
# if set VERNISSAGE_S3ADDRESS is overwritten to connect to Amazon AWS
# VERNISSAGE_S3REGION=

# name of your S3 bucket
VERNISSAGE_S3BUCKET=vernissage

# accesskey and secret to your S3 storage
VERNISSAGE_S3ACCESSKEYID=AcC3s5k3yXDqIV3t6wXF
VERNISSAGE_S3SECRETACCESSKEY=53cR3tXHuhiSoY7bXxbfTbKJS2vdKmlT6vs3kFdb

# connection string to your redis server
# no need to change if the preconfigured redis from docker-compose.yml is used
VERNISSAGE_QUEUEURL=redis://vernissage-redis.internal:6379

# set to debug to increase the log output
#LOG_LEVEL=debug


########################################################################
# WEB

# adress to add to the Content-Security-Policy-headers to access files
# on your S3 storage. Normaly the same as VERNISSAGE_S3ADDRESS
VERNISSAGE_CSP_IMG=https://minio.example.com


########################################################################
# PROXY

# exposed port under which the proxy will be accessible. mostly used for
# a nginx reverse proxy configuration on the host. default: 8080
#EXPOSED_PORT=8080


########################################################################
# PUSH

# random, password like string
# must be the same as in "WebPush service secret key" from /settings
VPUSH_KEY=vPu5h_K3yX3673hg627JZW72HD6738bz76HDE73JEzbhzFGIB75zgR5


########################################################################
# GLOBAL

# tag ("version") of docker containers to use. defaults to "latest"
# `docker compose pull` after changing this value
#DOCKER_TAG=latest

# subnet for internaly used IPv6 adresses
# defaults to 2001:db8::/64
#IPV6_SUBNET=2001:db8::/64
```

**Important:** Don't forget to `chmod 600 .env` to protect the passwords herein.


## Running your deployment

To startup Vernissage you need only run the `docker compose up` command from **HOME**

```
cd HOME
docker compose up -d
```

The parameter `-d` detaches the process. Or in other words: sends the process to the background

## Other useful commands

Always `cd HOME` before issuing one of the following commands

* Shutdown Vernissage: `docker compose down`
* Restart Vernissage: `docker compose down && docker compose up -d`
* Force update and restart: `docker compose down && docker compose pull && docker compose up -d`
* Quick status: `docker ps --format '{{.Names}}\t{{.Status}}' | grep $(basename $(pwd))-`
* View the running logs: `docker compose logs -f`

The containers also log to your syslog daemon
