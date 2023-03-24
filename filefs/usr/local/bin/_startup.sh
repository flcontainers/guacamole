#!/bin/sh
echo "Preparing Config Folder"
cp -rn /app/guacamole /config
mkdir -p /root/.config/freerdp/known_hosts

# Own postgres folder if exist (change to alpine)
if [ -d "/config/postgres/" ]; then
  chown -R postgres:postgres /config/postgres
  echo "Applied owners rights on Postgres folder..."
fi

# avoid DB locks after a bad shutdown...
if [ -f "/config/postgres/postmaster.pid" ]; then
  rm -f /config/postgres/postmaster.pid
  echo "DB lock removed..."
fi

# old file db check and location move
DB_FILE=/config/.database-version
if [ -f "$DB_FILE" ]; then
    rm -rf /config/db_check && \
    mkdir -p /config/db_check && \
    mv -f $DB_FILE /config/db_check && \
    chown -R postgres:postgres /config/db_check
    else
    mkdir -p /config/db_check && \
    chown -R postgres:postgres /config/db_check
fi

# enable extensions
for i in $(echo "$EXTENSIONS" | tr "," " "); do
  cp ${GUACAMOLE_HOME}/extensions-available/guacamole-${i}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions
done