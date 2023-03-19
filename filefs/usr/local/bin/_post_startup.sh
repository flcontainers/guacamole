#!/usr/bin/env bash

# Wait for postgres to be ready
until pg_isready; do
  echo "Waiting for postgres to come up..."
  sleep 1
done

# Create database if it does not exist
psql -U postgres -lqt | cut -d \| -f 1 | grep -qw $POSTGRES_DB
if [ $? -ne 0 ]; then
  createuser -U postgres $POSTGRES_USER
  createdb -U postgres -O $POSTGRES_USER $POSTGRES_DB
  cat /app/guacamole/schema/*.sql | psql -U $POSTGRES_USER -d $POSTGRES_DB -f -
  echo "$GUAC_VER" > /config/db_check/.database-version
else
  if [ "$(cat /config/db_check/.database-version)" != "$GUAC_VER" ]; then
    cat /app/guacamole/schema/upgrade/upgrade-pre-$GUAC_VER.sql | psql -U $POSTGRES_USER -d $POSTGRES_DB -f -
    echo "$GUAC_VER" > /config/db_check/.database-version
  fi
fi