#!/usr/bin/env bash
echo "Preparing Config Folder"
cp -rn /app/guacamole /config
mkdir -p /root/.config/freerdp/known_hosts

# enable extensions
for i in $(echo "$EXTENSIONS" | tr "," " "); do
  cp ${GUACAMOLE_HOME}/extensions-available/guacamole-${i}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions
done