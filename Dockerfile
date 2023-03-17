# Select BASE
FROM tomcat:9-jdk8

ARG APPLICATION="guacamole"
ARG BUILD_RFC3339="2023-03-17T15:00:00Z"
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

#Set working DIR
RUN mkdir -p ${GUACAMOLE_HOME}/{extensions,extensions-available,lib}
WORKDIR ${GUACAMOLE_HOME}

# Add support for bullseye-backports
RUN echo "deb http://deb.debian.org/debian bullseye-backports main contrib non-free" >> /etc/apt/sources.list

# Add essential utils
RUN set -xe && \
  apt-get update && apt-get install -y vim xz-utils \
  curl gpg gnupg2 software-properties-common apt-transport-https lsb-release ca-certificates

# Add Postgresql
RUN set -xe && \
apt-get update && apt-get install -y postgresql-${PG_MAJOR}

# Install dependencies
RUN set -xe && \
  apt-get -t bullseye-backports install -y \
  build-essential \
  ghostscript fonts-spleen fonty-rg\
  libcairo2-dev libjpeg62-turbo-dev libpng-dev libtool-bin uuid-dev libossp-uuid-dev \
  libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
  freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libwebsockets-dev libpulse-dev libssl-dev libvorbis-dev libwebp-dev

# Apply the s6-overlay
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then ARCH=amd64; elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then ARCH=aarch64; elif [ "$TARGETPLATFORM" = "linux/ppc64le" ]; then ARCH=powerpc64le; else ARCH=amd64; fi \
  && curl -SLO "https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-${ARCH}.tar.gz" \
  && tar -xzf s6-overlay-${ARCH}.tar.gz -C / \
  && tar -xzf s6-overlay-${ARCH}.tar.gz -C /usr ./bin \
  && rm -rf s6-overlay-${ARCH}.tar.gz

# Install guacamole-server
RUN curl -SLO "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/source/guacamole-server-${GUAC_VER}.tar.gz" \
&& tar -xzf ${GUACAMOLE_HOME}/guacamole-server-${GUAC_VER}.tar.gz \
&& cd ${GUACAMOLE_HOME}/guacamole-server-${GUAC_VER} \
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

# Purge BUild packages
RUN apt-get dist-upgrade -y
RUN apt-get purge -y build-essential xz-utils\

  && apt-get autoremove -y && apt-get autoclean \
  && rm -rf /var/lib/apt/lists/*

# Finishing Container configuration
ENV PATH=/usr/lib/postgresql/${PG_MAJOR}/bin:$PATH
ENV GUACAMOLE_HOME=/config/guacamole

WORKDIR /config

COPY rootfs /

ENTRYPOINT [ "/init" ]