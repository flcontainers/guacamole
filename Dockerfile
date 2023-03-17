# Select BASE
FROM tomcat:9-jdk8

ARG APPLICATION="guacamole"
ARG BUILD_RFC3339="2023-03-16T15:00:00Z"
ARG REVISION="local"
ARG DESCRIPTION="Guacamole 1.5.0"
ARG PACKAGE="MaxWaldorf/guacamole"
ARG VERSION="1.5.0"
ARG TARGETPLATFORM
ARG PG_MAJOR="13"
ARG S6_OVERLAY_VERSION="3.1.4.1"
# Do not require interaction during build
ARG DEBIAN_FRONTEND=noninteractive

STOPSIGNAL SIGKILL

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
  VERSION="${VERSION}" \
  S6_OVERLAY_VERSION="${S6_OVERLAY_VERSION}" \
  S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

ENV \
  GUAC_VER=${VERSION} \
  GUACAMOLE_HOME=/app/guacamole \
  PG_MAJOR=${PG_MAJOR} \
  PGDATA=/config/postgres \
  POSTGRES_USER=guacamole \
  POSTGRES_DB=guacamole_db

# Set working DIR
WORKDIR ${GUACAMOLE_HOME}

# Display variables (Test)
RUN echo "I'm building for TARGETPLATFORM=${TARGETPLATFORM}"

# Add support for Postgresql 13
RUN apt-get update && apt-get install -y curl gpg gnupg2 software-properties-common apt-transport-https lsb-release ca-certificates
RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list

# Install initial components
RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y xz-utils curl postgresql-${PG_MAJOR} ghostscript

#Add Fonts as requested by users
RUN apt-get install -y fonts-spleen fonty-rg

# Install dependencies
RUN apt-get install -y \
  build-essential \
  libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin uuid-dev libossp-uuid-dev \
  libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
  freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libwebsockets-dev libpulse-dev libssl-dev libvorbis-dev libwebp-dev

# Apply the s6-overlay
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; \
  then S6_ARCH=x86_64; \
elif [ "$TARGETPLATFORM" = "linux/arm/v6" ]; \
  then S6_ARCH=arm; \
elif [ "$TARGETPLATFORM" = "linux/arm/v7" ]; \
  then S6_ARCH=armhf; \
elif [ "$TARGETPLATFORM" = "linux/arm64" ]; \
  then S6_ARCH=aarch64; \
elif [ "$TARGETPLATFORM" = "linux/ppc64le" ]; \
  then S6_ARCH=powerpc64le; \
else S6_ARCH=x86_64; \
fi \
  && curl -SL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" > /tmp/s6-overlay-noarch.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
  && curl -SL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" > /tmp/s6-overlay-${S6_ARCH}.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-${S6_ARCH}.tar.xz \
  && curl -SL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz" > /tmp/s6-overlay-symlinks-noarch.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz
  #&& curl -SL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/syslogd-overlay-noarch.tar.xz" > /tmp/syslogd-overlay-noarch.tar.xz \
  #&& tar -C / -Jxpf /tmp/syslogd-overlay-noarch.tar.xz

# Create Required Directories for Guacamole
RUN mkdir -p ${GUACAMOLE_HOME} \
  ${GUACAMOLE_HOME}/lib \
  ${GUACAMOLE_HOME}/extensions

# Install guacamole-server
RUN curl -SLO "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/source/guacamole-server-${GUAC_VER}.tar.gz" \
  && tar -xzf guacamole-server-${GUAC_VER}.tar.gz \
  && cd guacamole-server-${GUAC_VER} \
  && ./configure \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && make install \
  && cd .. \
  && rm -rf guacamole-server-${GUAC_VER}.tar.gz guacamole-server-${GUAC_VER} \
  && ldconfig

# Install guacamole-client and postgres auth adapter
RUN set -x \
  && rm -rf ${CATALINA_HOME}/webapps/ROOT \
  && curl -SLo ${CATALINA_HOME}/webapps/ROOT.war "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-${GUAC_VER}.war" \
  && curl -SLo ${GUACAMOLE_HOME}/lib/postgresql-42.5.4.jar "https://jdbc.postgresql.org/download/postgresql-42.5.4.jar"

###############################################################################
################################# EXTENSIONS ##################################
###############################################################################

RUN mkdir ${GUACAMOLE_HOME}/extensions-available

# Download all extensions
RUN set -xe \
  && for ext_name in auth-duo auth-header auth-jdbc auth-json auth-ldap auth-quickconnect auth-sso auth-totp vault history-recording-storage; do \
  curl -SLO "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-${ext_name}-${GUAC_VER}.tar.gz" \
  && tar -xzf guacamole-${ext_name}-${GUAC_VER}.tar.gz \
  ;done

# Copy standalone extensions over to extensions-available folder
RUN set -xe \
  && for ext_name in auth-duo auth-header auth-json auth-ldap auth-quickconnect auth-totp history-recording-storage; do \
  cp guacamole-${ext_name}-${GUAC_VER}/guacamole-${ext_name}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  ;done

# Copy SSO extensions over to extensions-available folder
RUN set -xe \
  && for ext_name in openid saml cas; do \
  cp guacamole-auth-sso-${GUAC_VER}/${ext_name}/guacamole-auth-sso-${ext_name}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  ;done

# Copy JDBC extensions over to extensions-available folder
RUN set -xe \
  && for ext_name in mysql postgresql sqlserver; do \
  cp guacamole-auth-jdbc-${GUAC_VER}/${ext_name}/guacamole-auth-jdbc-${ext_name}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  ;done

# Copy vault extensions over to extensions-available folder
RUN set -xe \
  && for ext_name in ksm; do \
  cp guacamole-vault-${GUAC_VER}/${ext_name}/guacamole-vault-${ext_name}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
  ;done

# Clear all extensions leftovers
RUN set -xe \
  && for ext_name in auth-duo auth-header auth-jdbc auth-json auth-ldap auth-quickconnect auth-sso auth-totp vault history-recording-storage; do \
  rm -rf guacamole-${ext_name}-${GUAC_VER} guacamole-${ext_name}-${GUAC_VER}.tar.gz \
  ;done

###############################################################################
###############################################################################
###############################################################################

# Purge Build packages
RUN apt-get purge -y build-essential \
  && apt-get autoremove -y && apt-get autoclean \
  && rm -rf /var/lib/apt/lists/*

# Finishing Container configuration
ENV PATH=/usr/lib/postgresql/${PG_MAJOR}/bin:$PATH
ENV GUACAMOLE_HOME=/config/guacamole

WORKDIR /config

COPY rootfs /

ENTRYPOINT [ "/init" ]
