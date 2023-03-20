FROM debian:bullseye-slim

ARG APPLICATION="guacamole"
ARG BUILD_RFC3339="2023-03-17T15:00:00Z"
ARG REVISION="local"
ARG DESCRIPTION="Guacamole 1.5.0"
ARG PACKAGE="MaxWaldorf/guacamole"
ARG VERSION="1.5.0"
ARG TARGETPLATFORM
ARG POSTGRES_HOST_AUTH_METHOD="trust"
ARG DEBIAN_FRONTEND=noninteractive

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
  POSTGRES_HOST_AUTH_METHOD=${POSTGRES_HOST_AUTH_METHOD} \
  S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
  S6_BEHAVIOUR_IF_STAGE2_FAILS=1

SHELL ["/bin/bash", "-c"]

# Set working DIR
RUN mkdir -p /config /config/db_check
RUN mkdir -p ${GUACAMOLE_HOME}/extensions ${GUACAMOLE_HOME}/extensions-available ${GUACAMOLE_HOME}/lib
RUN mkdir /docker-entrypoint-initdb.d
WORKDIR ${GUACAMOLE_HOME}

# Add essential utils
RUN apt-get update && apt-get install -y bash vim curl build-essential gosu

# Install dependencies
RUN set -xe && \
  apt-get update && \
  apt-get install -y \
  openjdk-11-jdk postgresql-${PG_MAJOR} \
  ghostscript fonts-spleen fonty-rg \
  libcairo2-dev libjpeg62-turbo-dev libpng-dev libtool-bin uuid-dev libossp-uuid-dev \
  libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
  freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libwebsockets-dev libpulse-dev libssl-dev libvorbis-dev libwebp-dev

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

# Install guacamole-server
RUN curl -SLO "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/source/guacamole-server-${GUAC_VER}.tar.gz" \
&& tar -xzf ${GUACAMOLE_HOME}/guacamole-server-${GUAC_VER}.tar.gz \
&& cd ${GUACAMOLE_HOME}/guacamole-server-${GUAC_VER} \
&& ./configure --with-init-dir=/etc/init.d \
&& make \
&& make install \
&& ldconfig \
&& cd .. \
&& rm -rf guacamole-server-${GUAC_VER}.tar.gz guacamole-server-${GUAC_VER}

# Install guacamole-client and postgres auth adapter
RUN set -x \
  && rm -rf ${CATALINA_HOME}/webapps/ROOT \
  && curl -SLo ${CATALINA_HOME}/webapps/ROOT.war "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-${GUAC_VER}.war" \
  && curl -SLo ${GUACAMOLE_HOME}/lib/postgresql-42.6.0.jar "https://jdbc.postgresql.org/download/postgresql-42.6.0.jar" \
  && curl -SLO "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-auth-jdbc-${GUAC_VER}.tar.gz" \
  && tar -xzf guacamole-auth-jdbc-${GUAC_VER}.tar.gz \
  && cp -R guacamole-auth-jdbc-${GUAC_VER}/postgresql/guacamole-auth-jdbc-postgresql-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions/ \
  && cp -R guacamole-auth-jdbc-${GUAC_VER}/postgresql/schema ${GUACAMOLE_HOME}/ \
  && rm -rf guacamole-auth-jdbc-${GUAC_VER} guacamole-auth-jdbc-${GUAC_VER}.tar.gz

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

# Check vulnerabilities and Purge Build packages
RUN apt-get dist-upgrade -y \
  && apt-get purge -y build-essential \
  && apt-get autoremove -y && apt-get autoclean \
  && rm -rf /var/lib/apt/lists/*

# Finishing Container configuration
ENV PATH=/usr/lib/postgresql/${PG_MAJOR}/bin:$PATH
ENV GUACAMOLE_HOME=/config/guacamole

# Copy files
COPY filefs /
RUN chmod +x /usr/local/bin/*.sh
RUN chmod +x /etc/init.d/tomcat
RUN chmod +x /etc/init.d/postgres
RUN chmod +x /startup.sh
RUN chown -R postgres:postgres /config/db_check

# Hack for windows based host (CRLF / LF)
RUN sed -i -e 's/\r$//' /etc/init.d/*

# Docker Startup Scripts
WORKDIR /
ENTRYPOINT [ "/startup.sh" ]

EXPOSE 8080

WORKDIR /config
