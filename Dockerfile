ARG ALPINE_BASE_IMAGE=3.19
FROM alpine:${ALPINE_BASE_IMAGE} AS builder

ARG VERSION="1.5.5"
ARG TARGETPLATFORM

# FreeRDP version (default to version 3)
ARG FREERDP_VERSION=2

ENV \
  GUAC_VER=${VERSION}

# Install build dependencies
RUN apk add --no-cache        \
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
openssl-dev                   \
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
ARG WITH_FREERDP="${FREERDP_VERSION}(\.\d+)+"
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
    -DWITH_FFMPEG=ON \
    -DWITH_GSM=ON \
    -DWITH_GSSAPI=OFF \
    -DWITH_IPP=OFF \
    -DWITH_JPEG=ON \
    -DWITH_LIBSYSTEMD=OFF \
    -DWITH_MANPAGES=OFF \
    -DWITH_OPENH264=ON \
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
ARG DESCRIPTION="Fully Packaged and Multi-Arch Guacamole container"
ARG PACKAGE="flcontainers/guacamole"
ARG VERSION="1.5.5"

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
  TOMCAT_VER=9.0.91 \
  PGDATA=/config/postgres \
  POSTGRES_USER=guacamole \
  POSTGRES_DB=guacamole_db

# Runtime environment
ENV LC_ALL=C.UTF-8
ENV LD_LIBRARY_PATH=${PREFIX_DIR}/lib
ENV GUACD_LOG_LEVEL=info
ENV TZ=UTC

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
        postgresql${PG_MAJOR}         \
        pwgen                         \
        shadow                        \
        supervisor                    \
        terminus-font                 \
        ttf-dejavu                    \
        ttf-liberation                \
        tzdata                        \
        util-linux-login && \
    xargs apk add --no-cache < ${PREFIX_DIR}/DEPENDENCIES

RUN apk add --no-cache -X https://dl-cdn.alpinelinux.org/alpine/edge/testing gosu

# Create a new user guacd
ARG UID=1000
ARG GID=1000
RUN groupadd --gid $GID guacd
RUN useradd --system --create-home --shell /sbin/nologin --uid $UID --gid $GID guacd

RUN chown guacd:guacd -R ${PREFIX_DIR}

# Install tomcat
RUN mkdir ${CATALINA_HOME}
ADD https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz /tmp/
RUN tar xvzf /tmp/apache-tomcat-${TOMCAT_VER}.tar.gz --strip-components 1 --directory ${CATALINA_HOME}
RUN chmod +x ${CATALINA_HOME}/bin/*.sh

RUN groupadd tomcat && \
useradd -s /bin/false -g tomcat -d ${CATALINA_HOME} tomcat

RUN chgrp -R tomcat ${CATALINA_HOME} && \
chmod -R g+r ${CATALINA_HOME}/conf && \
chmod g+x ${CATALINA_HOME}/conf && \
chown -R tomcat ${CATALINA_HOME}/webapps/ ${CATALINA_HOME}/work/ ${CATALINA_HOME}/temp/ ${CATALINA_HOME}/logs/ && \
chmod 777 -R ${CATALINA_HOME}/logs/

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
RUN chown tomcat:tomcat -R ${GUACAMOLE_HOME}

ENV PATH=/usr/lib/postgresql/${PG_MAJOR}/bin:$PATH
ENV GUACAMOLE_HOME=/config/guacamole
ENV CATALINA_PID=/tmp/tomcat.pid
ENV POSTGRES_PID=/config/postgresql/postmaster.pid
ENV GUACD_PID=/tmp/guacd.pid

# Copy files
COPY filefs /
RUN chmod +x /usr/local/bin/*.sh
RUN chmod +x /startup.sh

# Copy Scripts
COPY scripts/tomcat ${CATALINA_HOME}/bin
RUN chown tomcat:tomcat ${CATALINA_HOME}/bin/wrapper_supervisor.sh
RUN chmod +x ${CATALINA_HOME}/bin/wrapper_supervisor.sh

COPY scripts/guacd ${PREFIX_DIR}
RUN chown guacd:guacd ${PREFIX_DIR}/wrapper_supervisor.sh
RUN chmod +x ${PREFIX_DIR}/wrapper_supervisor.sh

RUN mkdir -p /scripts/postgres
RUN chmod 755 -R /scripts
COPY scripts/postgres /scripts/postgres
RUN chown postgres:postgres -R /scripts/postgres
RUN chmod +x /scripts/postgres/wrapper_supervisor.sh

# Prepare logs folder for supervisor
RUN mkdir -p /var/log/supervisor
RUN chmod 755 -R /var/log/supervisor

# Stop Signal type
STOPSIGNAL SIGTERM

EXPOSE 8080

WORKDIR /config

# Set the entrypoint
ENTRYPOINT ["/startup.sh"]