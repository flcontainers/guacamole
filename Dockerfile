ARG ALPINE_BASE_IMAGE=latest
FROM alpine:${ALPINE_BASE_IMAGE} AS builder

ARG VERSION="1.5.0"
ARG TARGETPLATFORM

ENV \
  GUAC_VER=${VERSION}

# Install build dependencies (Note: ffmpeg4 because of bug in 1.5.0 will be fixed in 1.5.1+)
RUN apk add --no-cache                \
        alsa-lib-dev                  \
        alsa-tools-dev                \
        autoconf                      \
        automake                      \
        build-base                    \
        cairo-dev                     \
        cmake                         \
        cups-dev                      \
        faac-dev                      \
        faad2-dev                     \
        ffmpeg4-dev                   \
        git                           \
        grep                          \
        gsm-dev                       \
        gstreamer-dev                 \
        libjpeg-turbo-dev             \
        libpng-dev                    \
        libtool                       \
        libusb-dev                    \
        libwebp-dev                   \
        libxkbfile-dev                \
        make                          \
        openh264-dev                  \
        openssl1.1-compat-dev         \
        pango-dev                     \
        pcsc-lite-dev                 \
        pulseaudio-dev                \
        util-linux-dev


# Copy source to container for sake of build
ARG BUILD_DIR=/tmp/guacamole-server
RUN cd /tmp && \
git clone --branch=${GUAC_VER} https://github.com/apache/guacamole-server.git guacamole-server

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
ARG WITH_FREERDP='2(\.\d+)+'
ARG WITH_LIBSSH2='libssh2-\d+(\.\d+)+'
ARG WITH_LIBTELNET='\d+(\.\d+)+'
ARG WITH_LIBVNCCLIENT='LibVNCServer-\d+(\.\d+)+'
ARG WITH_LIBWEBSOCKETS='v\d+(\.\d+)+'

#
# Default build options for each core protocol support library, as well as
# guacamole-server itself (these can be overridden at build time if different
# options are needed)
#

ARG FREERDP_OPTS_COMMON="\
    -DBUILTIN_CHANNELS=OFF \
    -DCHANNEL_URBDRC=OFF \
    -DWITH_ALSA=ON \
    -DWITH_CAIRO=ON \
    -DWITH_CHANNELS=ON \
    -DWITH_CLIENT=ON \
    -DWITH_CUPS=ON \
    -DWITH_DIRECTFB=OFF \
    -DWITH_FAAC=ON \
    -DWITH_FAAD2=ON \
    -DWITH_FFMPEG=ON \
    -DWITH_GSM=ON \
    -DWITH_GSSAPI=OFF \
    -DWITH_IPP=OFF \
    -DWITH_JPEG=ON \
    -DWITH_LIBSYSTEMD=OFF \
    -DWITH_MANPAGES=OFF \
    -DWITH_OPENH264=N \
    -DWITH_OPENSSL=ON \
    -DWITH_OSS=OFF \
    -DWITH_PCSC=ON \
    -DWITH_PULSE=ON \
    -DWITH_SERVER=OFF \
    -DWITH_SERVER_INTERFACE=OFF \
    -DWITH_SHADOW_MAC=OFF \
    -DWITH_SHADOW_X11=OFF \
    -DWITH_WAYLAND=OFF \
    -DWITH_X11=OFF \
    -DWITH_X264=OFF \
    -DWITH_XCURSOR=ON \
    -DWITH_XEXT=ON \
    -DWITH_XI=OFF \
    -DWITH_XINERAMA=OFF \
    -DWITH_XKBFILE=ON \
    -DWITH_XRENDER=OFF \
    -DWITH_XTEST=OFF \
    -DWITH_XV=OFF \
    -DWITH_ZLIB=ON"

ARG GUACAMOLE_SERVER_OPTS="\
    --disable-guaclog"

ARG LIBSSH2_OPTS="\
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_SHARED_LIBS=ON"

ARG LIBTELNET_OPTS="\
    --disable-static \
    --disable-util"

ARG LIBVNCCLIENT_OPTS=""

ARG LIBWEBSOCKETS_OPTS="\
    -DDISABLE_WERROR=ON \
    -DLWS_WITHOUT_SERVER=ON \
    -DLWS_WITHOUT_TESTAPPS=ON \
    -DLWS_WITHOUT_TEST_CLIENT=ON \
    -DLWS_WITHOUT_TEST_PING=ON \
    -DLWS_WITHOUT_TEST_SERVER=ON \
    -DLWS_WITHOUT_TEST_SERVER_EXTPOLL=ON \
    -DLWS_WITH_STATIC=OFF"

# Build guacamole-server and its core protocol library dependencies
RUN echo "$TARGETPLATFORM"
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; \
    then FREERDP_OPTS="${FREERDP_OPTS_COMMON}    -DWITH_SSE2=ON" && echo "SSE2 active"; \
    else FREERDP_OPTS="${FREERDP_OPTS_COMMON}    -DWITH_SSE2=OFF" && echo "SSE2 disabled"; \
    fi && \
${BUILD_DIR}/src/guacd-docker/bin/build-all.sh

# Record the packages of all runtime library dependencies
RUN ${BUILD_DIR}/src/guacd-docker/bin/list-dependencies.sh \
        ${PREFIX_DIR}/sbin/guacd               \
        ${PREFIX_DIR}/lib/libguac-client-*.so  \
        ${PREFIX_DIR}/lib/freerdp2/*guac*.so   \
        > ${PREFIX_DIR}/DEPENDENCIES


# Use same Alpine version as the base for the runtime image
FROM alpine:${ALPINE_BASE_IMAGE}

ARG PREFIX_DIR=/opt/guacamole

ARG APPLICATION="guacamole"
ARG BUILD_RFC3339="2023-04-04T13:00:00Z"
ARG REVISION="local"
ARG DESCRIPTION="Fully Pacaged and Multi-Arch Guacamole container"
ARG PACKAGE="flcontainers/guacamole"
ARG VERSION="1.5.0"
ARG POSTGRES_HOST_AUTH_METHOD="trust"

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
  GUAC_VER=${VERSION} \
  GUACAMOLE_HOME=/app/guacamole \
  CATALINA_HOME=/opt/tomcat \
  PG_MAJOR=13 \
  PGDATA=/config/postgres \
  POSTGRES_USER=guacamole \
  POSTGRES_DB=guacamole_db \
  POSTGRES_HOST_AUTH_METHOD=${POSTGRES_HOST_AUTH_METHOD}

# Runtime environment
ENV LC_ALL=C.UTF-8
ENV LD_LIBRARY_PATH=${PREFIX_DIR}/lib
ENV GUACD_LOG_LEVEL=info

# Copy build artifacts into this stage
COPY --from=builder ${PREFIX_DIR} ${PREFIX_DIR}

# Set working DIR
RUN mkdir -p /config
RUN mkdir -p ${GUACAMOLE_HOME}/extensions ${GUACAMOLE_HOME}/extensions-available ${GUACAMOLE_HOME}/lib
RUN mkdir /docker-entrypoint-initdb.d
WORKDIR ${GUACAMOLE_HOME}

# Bring runtime environment up to date and install runtime dependencies
RUN apk add --no-cache                \
        bash                          \
        bash-completion               \
        ca-certificates               \
        curl                          \
        ghostscript                   \
        netcat-openbsd                \
        openjdk11-jdk                 \
        postgresql13                  \
        shadow                        \
        terminus-font                 \
        ttf-dejavu                    \
        ttf-liberation                \
        util-linux-login && \
    xargs apk add --no-cache < ${PREFIX_DIR}/DEPENDENCIES

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

STOPSIGNAL SIGINT

# Docker Startup Scripts
WORKDIR /
CMD ["/startup.sh"]

EXPOSE 8080

WORKDIR /config
