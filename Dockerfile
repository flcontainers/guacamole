ARG ALPINE_BASE_IMAGE=latest
FROM alpine:${ALPINE_BASE_IMAGE} AS builder

ARG APPLICATION="guacamole"
ARG BUILD_RFC3339="2023-03-17T15:00:00Z"
ARG REVISION="local"
ARG DESCRIPTION="Guacamole 1.5.0"
ARG PACKAGE="MaxWaldorf/guacamole"
ARG VERSION="1.5.0"
ARG POSTGRES_HOST_AUTH_METHOD="trust"

STOPSIGNAL SIGINT

LABEL org.opencontainers.image.ref.name="${PACKAGE}" \
  org.opencontainers.image.created=$BUILD_RFC3339 \
  org.opencontainers.image.authors="MaxWaldorf" \
  org.opencontainers.image.documentation="https://github.com/${PACKAGE}/README.md" \
  org.opencontainers.image.description="${DESCRIPTION}" \
  org.opencontainers.image.licenses="GPLv3" \
  org.opencontainers.image.source="https://github.com/${PACKAGE}" \
  org.opencontainers.image.revision=$REVISION \
  org.opencontainers.image.version=$VERSION \
  org.opencontainers.image.url="https://hub.docker.com/r/${PACKAGE}/"

ENV \
  APPLICATION="${APPLICATION}" \
  BUILD_RFC3339="${BUILD_RFC3339}" \
  REVISION="${REVISION}" \
  DESCRIPTION="${DESCRIPTION}" \
  PACKAGE="${PACKAGE}" \
  VERSION="${VERSION}"

ENV \
  GUAC_VER=${VERSION} \
  GUACAMOLE_HOME=/app/guacamole \
  CATALINA_HOME=/opt/tomcat \
  PG_MAJOR=13 \
  PGDATA=/config/postgres \
  POSTGRES_USER=guacamole \
  POSTGRES_DB=guacamole_db \
  POSTGRES_HOST_AUTH_METHOD=${POSTGRES_HOST_AUTH_METHOD}

# Builder

# Install build dependencies
RUN apk add --no-cache                \
        git                                                                                           \
        make                                                                                          \
        automake                                                                                      \
        autoconf                                                                                      \
        cmake                                                                                         \
        gcc                                                                                           \
        libtool                                                                                       \
        build-base                                                                                    \
        linux-headers                                                                                 \
        bsd-compat-headers                                                                            \
        intltool                                                                                      \
        musl-dev                                                                                      \
        cairo-dev                                                                                     \
        libjpeg-turbo-dev                                                                             \
        libpng-dev                                                                                    \
        pango-dev                                                                                     \
        libssh2-dev                                                                                   \
        libvncserver-dev                                                                              \
        openssl-dev                                                                                   \
        libvorbis-dev                                                                                 \
        libwebp-dev                                                                                   \
        libsndfile-dev                                                                                \
        pulseaudio-dev                                                                                \
        libusb-dev                                                                                    \
        freerdp-dev                                                                                   \
        libwebsockets-dev \
        util-linux-dev


# Copy source to container for sake of build
ARG BUILD_DIR=/tmp/guacamole-server

#
# Base directory for installed build artifacts.
#
# NOTE: Due to limitations of the Docker image build process, this value is
# duplicated in an ARG in the second stage of the build.
#
ARG PREFIX_DIR=/opt/guacamole

#
# Automatically select the latest versions of each core protocol support
# library (these can be overridden at build time if a specific version is
# needed)
#
ARG WITH_LIBTELNET='\d+(\.\d+)+'

#
# Default build options for each core protocol support library, as well as
# guacamole-server itself (these can be overridden at build time if different
# options are needed)
#

ARG GUACAMOLE_SERVER_OPTS="\
    --disable-guaclog"

ARG LIBTELNET_OPTS="\
    --disable-static \
    --disable-util"

# Build libtelnet
RUN cd /tmp && \
    git clone --branch 0.23 https://github.com/seanmiddleditch/libtelnet.git && \
    cd /tmp/libtelnet                                                                  && \
    autoreconf -i                                                                      && \
    autoconf                                                                           && \
    ./configure --prefix="$PREFIX_DIR" "$@"                                                                        && \
    make                                                                               && \
    make install 

# Build guacamole-server and its core protocol library dependencies
RUN cd /tmp && \
git clone --branch=${GUAC_VER} https://github.com/apache/guacamole-server.git guacamole-server && \
cd guacamole-server && \
autoreconf -fi && \
autoconf && \
./configure --prefix="$PREFIX_DIR" $GUACAMOLE_SERVER_OPTS && \
make && \
make install 

# Use same Alpine version as the base for the runtime image
FROM alpine:${ALPINE_BASE_IMAGE}

ARG PREFIX_DIR=/opt/guacamole
ARG VERSION="1.5.0"
ARG POSTGRES_HOST_AUTH_METHOD="trust"

ENV \
  GUAC_VER=${VERSION} \
  GUACAMOLE_HOME=/app/guacamole \
  CATALINA_HOME=/opt/tomcat \
  PG_MAJOR=13 \
  PGDATA=/config/postgres \
  POSTGRES_USER=guacamole \
  POSTGRES_DB=guacamole_db \
  POSTGRES_HOST_AUTH_METHOD=${POSTGRES_HOST_AUTH_METHOD}

# Set working DIR
RUN mkdir -p /config
RUN mkdir -p ${GUACAMOLE_HOME}/extensions ${GUACAMOLE_HOME}/extensions-available ${GUACAMOLE_HOME}/lib
RUN mkdir /docker-entrypoint-initdb.d
WORKDIR ${GUACAMOLE_HOME}

# Runtime environment
ENV LC_ALL=C.UTF-8
ENV LD_LIBRARY_PATH=${PREFIX_DIR}/lib
ENV GUACD_LOG_LEVEL=info

# Copy build artifacts into this stage
COPY --from=builder ${PREFIX_DIR} ${PREFIX_DIR}

# Bring runtime environment up to date and install runtime dependencies
RUN apk add --no-cache                \
        bash                          \
        bash-completion               \
        curl                          \
        netcat-openbsd                \
        ca-certificates               \
        ghostscript                   \
        openjdk11-jdk                 \
        postgresql13                  \
        netcat-openbsd                \
        shadow                        \
        terminus-font                 \
        ttf-dejavu                    \
        ttf-liberation                \
        util-linux-login              \
        cairo                         \
        libjpeg-turbo                 \
        libpng                        \
        pango                         \
        libssh2                       \
        libvncserver                  \
        openssl                       \
        libvorbis                     \
        libwebp                       \
        libsndfile                    \
        pulseaudio                    \
        libusb                        \
        freerdp                       \
        libwebsockets                 \
        util-linux

RUN apk add --no-cache -X https://dl-cdn.alpinelinux.org/alpine/edge/testing gosu 

# Install tomcat
RUN mkdir /opt/tomcat
ADD https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.73/bin/apache-tomcat-9.0.73.tar.gz /tmp/
RUN tar xvzf /tmp/apache-tomcat-9.0.73.tar.gz --strip-components 1 --directory /opt/tomcat
RUN chmod +x /opt/tomcat/bin/*.sh

RUN groupadd tomcat && \
useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat

RUN chgrp -R tomcat /opt/tomcat && \
chmod -R g+r /opt/tomcat/conf && \
chmod g+x /opt/tomcat/conf && \
chown -R tomcat /opt/tomcat/webapps/ /opt/tomcat/work/ /opt/tomcat/temp/ /opt/tomcat/logs/

# Install guacamole-client and postgres auth adapter
RUN set -x \
  && rm -rf ${CATALINA_HOME}/webapps/ROOT \
  && curl -SLo ${CATALINA_HOME}/webapps/ROOT.war "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-${GUAC_VER}.war" \
  && curl -SLo ${GUACAMOLE_HOME}/lib/postgresql-42.6.0.jar "https://jdbc.postgresql.org/download/postgresql-42.6.0.jar" \
  && curl -SLo ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER}.tar.gz "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-auth-jdbc-${GUAC_VER}.tar.gz" \
  && tar -xzf ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER}.tar.gz \
  && cp -R ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER}/postgresql/guacamole-auth-jdbc-postgresql-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions/ \
  && cp -R ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER}/postgresql/schema ${GUACAMOLE_HOME}/ \
  && rm -rf ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER} ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER}.tar.gz

###############################################################################
################################# EXTENSIONS ##################################
###############################################################################

# Download all extensions
RUN set -xe \
  && for ext_name in auth-duo auth-header auth-jdbc auth-json auth-ldap auth-quickconnect auth-sso auth-totp vault history-recording-storage; do \
  curl -SLo ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER}.tar.gz "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-${ext_name}-${GUAC_VER}.tar.gz" \
  && tar -xzf ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER}.tar.gz \
  ;done

# Copy standalone extensions over to extensions-available folder
RUN set -xe \
  && for ext_name in auth-duo auth-header auth-json auth-ldap auth-quickconnect auth-totp history-recording-storage; do \
  cp ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER}/guacamole-${ext_name}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  ;done

# Copy SSO extensions over to extensions-available folder
RUN set -xe \
  && for ext_name in openid saml cas; do \
  cp ${GUACAMOLE_HOME}/guacamole-auth-sso-${GUAC_VER}/${ext_name}/guacamole-auth-sso-${ext_name}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  ;done

# Copy JDBC extensions over to extensions-available folder
RUN set -xe \
  && for ext_name in mysql postgresql sqlserver; do \
  cp ${GUACAMOLE_HOME}/guacamole-auth-jdbc-${GUAC_VER}/${ext_name}/guacamole-auth-jdbc-${ext_name}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  ;done

# Copy vault extensions over to extensions-available folder
RUN set -xe \
  && for ext_name in ksm; do \
  cp ${GUACAMOLE_HOME}/guacamole-vault-${GUAC_VER}/${ext_name}/guacamole-vault-${ext_name}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  ;done

# Clear all extensions leftovers
RUN set -xe \
  && for ext_name in auth-duo auth-header auth-jdbc auth-json auth-ldap auth-quickconnect auth-sso auth-totp vault history-recording-storage; do \
  rm -rf ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER} ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER}.tar.gz \
  ;done

###############################################################################
###############################################################################
###############################################################################

# Finishing Container configuration
ENV PATH=/usr/lib/postgresql/${PG_MAJOR}/bin:$PATH
ENV GUACAMOLE_HOME=/config/guacamole

# Copy files
COPY filefs /
RUN chmod +x /usr/local/bin/*.sh
RUN chmod +x /etc/init.d/tomcat
RUN chmod +x /etc/init.d/postgres
RUN chmod +x /startup.sh

# Hack for windows based host (CRLF / LF)
RUN sed -i -e 's/\r$//' /etc/init.d/*
RUN sed -i -e 's/\r$//' /usr/local/bin/*.sh
RUN sed -i -e 's/\r$//' /startup.sh

SHELL ["/bin/bash", "-c"]

# Docker Startup Scripts
WORKDIR /
CMD ["/startup.sh"]

EXPOSE 8080

WORKDIR /config
