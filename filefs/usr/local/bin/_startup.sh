#!/usr/bin/env bash
echo "Preparing Config Folder"
cp -rn /app/guacamole /config
mkdir -p /root/.config/freerdp/known_hosts

# old file db check and location move
DB_FILE=/config/.database-version
if [ -f "$DB_FILE" ]; then
    mv -f $DB_FILE /config/db_check && chown postgres:postgres /config/db_check/.database-version
fi

# enable extensions
for i in $(echo "$EXTENSIONS" | tr "," " "); do
  cp ${GUACAMOLE_HOME}/extensions-available/guacamole-${i}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions
done