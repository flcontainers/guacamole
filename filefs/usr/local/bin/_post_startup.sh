#!/usr/bin/env bash

# Wait for postgres to be ready
until pg_isready; do
  echo "Waiting for postgres to come up..."
  sleep 1
done

# Create database if it does not exist
if [ -f "/config/db_check/.database-version"]; then
  if [ "$(cat /config/db_check/.database-version)" != "$GUAC_VER" ]; then
    if [ -f "/app/guacamole/schema/upgrade/upgrade-pre-$GUAC_VER.sql"]: then
    cat /app/guacamole/schema/upgrade/upgrade-pre-$GUAC_VER.sql | psql -U $POSTGRES_USER -d $POSTGRES_DB -f -
    echo "$GUAC_VER" > /config/db_check/.database-version
    echo "guacamole database updated to $GUAC_VER"
    fi
  else
    echo "guacamole database already up-to-date. Nothing applied..."
  fi
else
  cat /app/guacamole/schema/*.sql | psql -U $POSTGRES_USER -d $POSTGRES_DB -f -
  echo "$GUAC_VER" > /config/db_check/.database-version
fi