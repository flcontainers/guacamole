[![Docker Image CI](https://github.com/MaxWaldorf/guacamole/actions/workflows/docker-image.yml/badge.svg)](https://github.com/MaxWaldorf/guacamole/actions/workflows/docker-image.yml) [![Docker Pulls](https://img.shields.io/docker/pulls/maxwaldorf/guacamole.svg)](https://hub.docker.com/r/maxwaldorf/guacamole/)

# Docker Guacamole

**Disclaimer:** This work is based on the work of: https://github.com/oznu/docker-guacamole

A Docker Container for [Apache Guacamole](https://guacamole.apache.org/), a client-less remote desktop gateway. It supports standard protocols like VNC, RDP, and SSH over HTML5.

This image will run on most platforms that support Docker including Docker for arm64 boards (Raspberry ARM64v8 on an 64bit OS).

This container runs the guacamole web client, the guacd server and a postgres database.

## Usage (works for x86_64 and arm64v8, no support for 32 bits)

```shell
docker run \
  -p 8080:8080 \
  -v </path/to/config>:/config \
  maxwaldorf/guacamole
```

## Parameters

The parameters are split into two halves, separated by a colon, the left hand side representing the host and the right the container side.

* `-p 8080:8080` - Binds the service to port 8080 on the Docker host, **required**
* `-v /config` - The config and database location, **required**
* `-e EXTENSIONS` - See below for details.

## Enabling Extensions

Extensions can be enabled using the `-e EXTENSIONS` variable. Multiple extensions can be enabled using a comma separated list without spaces.

For example:

```shell
docker run \
  -p 8080:8080 \
  -v </path/to/config>:/config \
  -e "EXTENSIONS=auth-ldap,auth-duo"
  maxwaldorf/guacamole
```

**Extension List:**
- auth-duo
- auth-header
- auth-jdbc-mysql
- auth-jdbc-postgresql
- auth-jdbc-sqlserver
- auth-json
- auth-ldap
- auth-quickconnect
- auth-sso-openid
- auth-sso-saml
- auth-sso-cas
- auth-totp

More information: [Guacamole v1.4.0 release notes](https://guacamole.apache.org/releases/1.4.0/)

You should only enable the extensions you require, if an extensions is not configured correctly in the `guacamole.properties` file it may prevent the system from loading. See the [official documentation](https://guacamole.apache.org/doc/gug/) for more details.

## Default User

The default username is `guacadmin` with password `guacadmin`.

## Windows-based Docker Hosts

Mapped volumes behave differently when running Docker for Windows and you may encounter some issues with PostgreSQL file system permissions. To avoid these issues, and still retain your config between container upgrades and recreation, you can use the local volume driver, as shown in the `docker-compose.yml` example below. When using this setup be careful to gracefully stop the container or data may be lost.

```yml
version: "2"
services:
  guacamole:
    image: maxwaldorf/guacamole
    container_name: guacamole
    volumes:
      - postgres:/config
    ports:
      - 8080:8080
volumes:
  postgres:
    driver: local
```

## License

(Based on OZNU choice GPLv3)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the [GNU General Public License](./LICENSE) for more details.

