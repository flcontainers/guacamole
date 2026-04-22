ARG VERSION="1.6.0"
ARG ALPINE_BASE_IMAGE=3.21
ARG PREFIX_DIR=/opt/guacamole
ARG BUILD_DIR=/tmp/guacamole-server
ARG OLD_PG_MAJOR=13
ARG OLD_PG_VERSION=13.23
ARG LIBTELNET_VERSION=0.23
ARG FREERDP_VERSION=3.24.2

FROM alpine:${ALPINE_BASE_IMAGE} AS libtelnet-builder

ARG PREFIX_DIR
ARG LIBTELNET_VERSION

RUN apk add --no-cache                \
    autoconf                      \
    automake                      \
    build-base                    \
    libtool                       \
    make                          \
    pkgconf                       \
    tar                           \
    wget                          \
    zlib-dev

RUN set -eux; \
  wget -O /tmp/libtelnet.tar.gz "https://github.com/seanmiddleditch/libtelnet/releases/download/${LIBTELNET_VERSION}/libtelnet-${LIBTELNET_VERSION}.tar.gz"; \
  mkdir -p /tmp/libtelnet-src; \
  tar -xzf /tmp/libtelnet.tar.gz -C /tmp/libtelnet-src --strip-components=1; \
  cd /tmp/libtelnet-src; \
  ./configure --prefix="${PREFIX_DIR}"; \
  make -j"$(getconf _NPROCESSORS_ONLN)"; \
  make install

FROM alpine:${ALPINE_BASE_IMAGE} AS freerdp-builder

ARG PREFIX_DIR
ARG FREERDP_VERSION

RUN apk add --no-cache                \
    build-base                        \
    cjson-dev                         \
    cmake                             \
    faac-dev                          \
    faad2-dev                         \
    ffmpeg-dev                        \
    gsm-dev                           \
    icu-dev                           \
    krb5-dev                          \
    libjpeg-turbo-dev                 \
    ninja                             \
    openh264-dev                      \
    openssl-dev                       \
    x264-dev                          \
    opus-dev                          \
    pkgconf                           \
    pulseaudio-dev                    \
    soxr-dev                          \
    tar                               \
    wget

RUN set -eux; \
  wget -O /tmp/freerdp.tar.gz "https://github.com/FreeRDP/FreeRDP/archive/refs/tags/${FREERDP_VERSION}.tar.gz"; \
  mkdir -p /tmp/freerdp-src; \
  tar -xzf /tmp/freerdp.tar.gz -C /tmp/freerdp-src --strip-components=1; \
  cmake -S /tmp/freerdp-src -B /tmp/freerdp-build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX_DIR}" \
    -DCMAKE_PREFIX_PATH="${PREFIX_DIR}" \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=OFF \
    -DBUILTIN_CHANNELS=OFF \
    -DCHANNEL_URBDRC=OFF \
    -DWITH_ALSA=OFF \
    -DWITH_CAIRO=OFF \
    -DWITH_CHANNELS=ON \
    -DWITH_CLIENT=ON \
    -DWITH_CLIENT_CHANNELS=ON \
    -DWITH_CLIENT_SDL=OFF \
    -DWITH_CUPS=OFF \
    -DWITH_DIRECTFB=OFF \
    -DWITH_DSP_FFMPEG=ON \
    -DWITH_FAAC=ON \
    -DWITH_FAAD2=ON \
    -DWITH_FFMPEG=ON \
    -DWITH_FUSE=OFF \
    -DWITH_GSM=ON \
    -DWITH_GSSAPI=OFF \
    -DWITH_IPP=OFF \
    -DWITH_JPEG=ON \
    -DWITH_KRB5=ON \
    -DWITH_MANPAGES=OFF \
    -DWITH_OPENH264=ON \
    -DWITH_OPENH264_LOADING=ON \
    -DWITH_OPENSSL=ON \
    -DWITH_OPUS=ON \
    -DWITH_OSS=OFF \
    -DWITH_PCSC=OFF \
    -DWITH_PKCS11=OFF \
    -DWITH_PULSE=ON \
    -DWITH_SAMPLE=OFF \
    -DWITH_SERVER=OFF \
    -DWITH_SERVER_INTERFACE=OFF \
    -DWITH_SHADOW=OFF \
    -DWITH_SWSCALE=ON \
    -DWITH_SOXR=ON \
    -DWITH_VIDEO_FFMPEG=ON \
    -DWITH_WAYLAND=OFF \
    -DWITH_X11=OFF \
    -DWITH_X264=ON; \
  cmake --build /tmp/freerdp-build --parallel "$(getconf _NPROCESSORS_ONLN)"; \
  cmake --install /tmp/freerdp-build

# Build guacd from source with a broad set of optional protocol/codec deps.
FROM alpine:${ALPINE_BASE_IMAGE} AS guacd-builder

ARG VERSION
ARG PREFIX_DIR
ARG BUILD_DIR

COPY --from=libtelnet-builder ${PREFIX_DIR} ${PREFIX_DIR}
COPY --from=freerdp-builder ${PREFIX_DIR} ${PREFIX_DIR}

RUN apk add --no-cache                \
        autoconf                      \
        automake                      \
        build-base                    \
        cairo-dev                     \
        cjson-dev                     \
        ffmpeg-dev                    \
        git                           \
        krb5-dev                      \
        libjpeg-turbo-dev             \
        libpng-dev                    \
        libssh2-dev                   \
        libtool                       \
        libvncserver-dev              \
        libvorbis-dev                 \
        libwebp-dev                   \
        libwebsockets-dev             \
        make                          \
        openh264-dev                  \
        openssl-dev                   \
        pango-dev                     \
        pkgconf                       \
        pulseaudio-dev                \
        tar                           \
        util-linux-dev                \
        wget                          \
        x264-dev

RUN set -eux; \
  rm -rf "${BUILD_DIR}"; \
  export CFLAGS="${CFLAGS:+${CFLAGS} }-Wno-error=deprecated-declarations"; \
  export CXXFLAGS="${CXXFLAGS:+${CXXFLAGS} }-Wno-error=deprecated-declarations"; \
  export CPPFLAGS="-I${PREFIX_DIR}/include"; \
  export LDFLAGS="-L${PREFIX_DIR}/lib"; \
  export PKG_CONFIG_PATH="${PREFIX_DIR}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"; \
    wget -O /tmp/guacamole-server.tar.gz "https://archive.apache.org/dist/guacamole/${VERSION}/source/guacamole-server-${VERSION}.tar.gz"; \
    tar -xzf /tmp/guacamole-server.tar.gz -C /tmp; \
    mv "/tmp/guacamole-server-${VERSION}" "${BUILD_DIR}"; \
    cd "${BUILD_DIR}"; \
    sed -i \
      's/freerdp_settings_set_bool(rdp_settings, FreeRDP_SupportGraphicsPipeline, TRUE);/freerdp_settings_set_bool(rdp_settings, FreeRDP_SupportGraphicsPipeline, TRUE);\n        freerdp_settings_set_bool(rdp_settings, FreeRDP_GfxH264, TRUE);\n        freerdp_settings_set_bool(rdp_settings, FreeRDP_GfxAVC444, TRUE);/' \
      "${BUILD_DIR}/src/protocols/rdp/settings.c"; \
    sed -i \
      's/rdp_settings->SupportGraphicsPipeline = TRUE;/rdp_settings->SupportGraphicsPipeline = TRUE;\n        rdp_settings->GfxH264 = TRUE;\n        rdp_settings->GfxAVC444 = TRUE;/' \
      "${BUILD_DIR}/src/protocols/rdp/settings.c"; \
    ./configure \
      --prefix="${PREFIX_DIR}" \
      --with-kubernetes \
      --with-libavcodec \
      --with-libavformat \
      --with-libavutil \
      --with-libswscale \
      --with-pulse \
      --with-rdp \
      --with-ssh \
      --with-telnet \
      --with-vnc \
      --with-webp; \
    make -j"$(getconf _NPROCESSORS_ONLN)"; \
    make install

RUN set -eux; \
    wget -O /tmp/list-dependencies.sh https://raw.githubusercontent.com/apache/guacamole-server/main/src/guacd-docker/bin/list-dependencies.sh; \
    chmod +x /tmp/list-dependencies.sh; \
    FREERDP_PLUGINS="$(find "${PREFIX_DIR}/lib" -type f -path '*/freerdp*/*guac*.so' || true)"; \
    /tmp/list-dependencies.sh \
      "${PREFIX_DIR}/sbin/guacd" \
      ${PREFIX_DIR}/lib/libguac-client-*.so \
      $FREERDP_PLUGINS \
      > "${PREFIX_DIR}/DEPENDENCIES"

FROM alpine:${ALPINE_BASE_IMAGE} AS postgres13-builder

ARG OLD_PG_MAJOR
ARG OLD_PG_VERSION

RUN apk add --no-cache                \
        bison                         \
        build-base                    \
        flex                          \
        linux-headers                 \
        openssl-dev                   \
        perl                          \
        perl-dev                      \
        tar                           \
        util-linux-dev                \
        wget                          \
        zlib-dev

RUN set -eux; \
    wget -O /tmp/postgresql.tar.bz2 "https://ftp.postgresql.org/pub/source/v${OLD_PG_VERSION}/postgresql-${OLD_PG_VERSION}.tar.bz2"; \
    mkdir -p /tmp/postgresql-src; \
    tar -xjf /tmp/postgresql.tar.bz2 -C /tmp/postgresql-src --strip-components=1; \
    cd /tmp/postgresql-src; \
    ./configure \
      --prefix="/opt/postgresql${OLD_PG_MAJOR}" \
      --with-openssl \
      --with-uuid=e2fs \
      --without-readline; \
    make -j"$(getconf _NPROCESSORS_ONLN)"; \
    make install

FROM alpine:${ALPINE_BASE_IMAGE} AS runtime

ARG PREFIX_DIR
ARG OLD_PG_MAJOR
COPY --from=guacd-builder ${PREFIX_DIR} ${PREFIX_DIR}
COPY --from=postgres13-builder /opt/postgresql${OLD_PG_MAJOR} /opt/postgresql${OLD_PG_MAJOR}

ARG VERSION
ARG APPLICATION="guacamole"
ARG BUILD_RFC3339="2025-07-07T23:00:00Z"
ARG REVISION="local"
ARG DESCRIPTION="Fully Packaged and Multi-Arch Guacamole container"
ARG PACKAGE="flcontainers/guacamole"

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
  OLD_PG_MAJOR=${OLD_PG_MAJOR} \
  PG_MAJOR=16 \
  PGDATA=/config/postgres \
  POSTGRES_USER=guacamole \
  POSTGRES_DB=guacamole_db

# Runtime environment
ENV LC_ALL=C.UTF-8
ENV LD_LIBRARY_PATH=${PREFIX_DIR}/lib
ENV GUACD_LOG_LEVEL=info
ENV TZ=UTC

# Set working DIR
USER root
RUN mkdir -p /config
RUN mkdir -p ${GUACAMOLE_HOME}/extensions ${GUACAMOLE_HOME}/extensions-available ${GUACAMOLE_HOME}/lib
RUN mkdir /docker-entrypoint-initdb.d
WORKDIR ${GUACAMOLE_HOME}

# Bring runtime environment up to date and install runtime dependencies
RUN apk add --no-cache                \
        bash                          \
        bash-completion               \
        ca-certificates               \
        coreutils                     \
        curl                          \
        font-noto-cjk                 \
        ghostscript                   \
        netcat-openbsd                \
        openh264                      \
        x264-libs                     \
        openjdk11-jdk                 \
        postgresql${PG_MAJOR}         \
        postgresql${PG_MAJOR}-client  \
        pwgen                         \
        shadow                        \
        supervisor                    \
        terminus-font                 \
        ttf-dejavu                    \
        ttf-liberation                \
        tzdata                        \
        util-linux-login && \
    xargs apk add --no-cache < ${PREFIX_DIR}/DEPENDENCIES

RUN apk add --no-cache -X https://dl-cdn.alpinelinux.org/alpine/edge/community gosu

RUN groupadd --gid 1000 guacd && \
    useradd --system --create-home --shell /sbin/nologin --uid 1000 --gid 1000 guacd

RUN chown guacd:guacd -R ${PREFIX_DIR}

# Install tomcat (robust TOMCAT_VER extraction)
RUN mkdir -p ${CATALINA_HOME} && \
    export TOMCAT_VER=$(curl -s https://dlcdn.apache.org/tomcat/tomcat-9/ \
      | grep -Eo 'v9\.[0-9]+\.[0-9]+/' \
      | sed 's|/||' | sed 's|v||' \
      | sort -V | tail -n1) && \
    echo "Latest Tomcat version: $TOMCAT_VER" && \
    curl -SLo /tmp/apache-tomcat.tar.gz "https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz" && \
    tar xvzf /tmp/apache-tomcat.tar.gz --strip-components 1 --directory ${CATALINA_HOME} && \
    chmod +x ${CATALINA_HOME}/bin/*.sh

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
  && curl -SLo ${GUACAMOLE_HOME}/lib/postgresql-42.7.7.jar "https://jdbc.postgresql.org/download/postgresql-42.7.7.jar" \
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
  && for ext_name in auth-duo auth-header auth-jdbc auth-json auth-ldap auth-quickconnect auth-sso auth-totp auth-ban display-statistics vault history-recording-storage; do \
  curl -SLo ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER}.tar.gz "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-${ext_name}-${GUAC_VER}.tar.gz" \
  && tar -xzf ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER}.tar.gz \
  ;done

# Copy standalone extensions over to extensions-available folder
RUN set -xe \
  && for ext_name in auth-duo auth-header auth-json auth-ldap auth-quickconnect auth-totp auth-ban display-statistics history-recording-storage; do \
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
  && for ext_name in auth-duo auth-header auth-jdbc auth-json auth-ldap auth-quickconnect auth-sso auth-totp auth-ban display-statistics vault history-recording-storage; do \
  rm -rf ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER} ${GUACAMOLE_HOME}/guacamole-${ext_name}-${GUAC_VER}.tar.gz \
  ;done

###############################################################################
###############################################################################
###############################################################################

# Finishing Container configuration
RUN chown tomcat:tomcat -R ${GUACAMOLE_HOME}

ENV PATH=/usr/libexec/postgresql${PG_MAJOR}:$PATH
ENV GUACAMOLE_HOME=/config/guacamole
ENV CATALINA_PID=/tmp/tomcat.pid
ENV POSTGRES_PID=/config/postgres/postmaster.pid
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
