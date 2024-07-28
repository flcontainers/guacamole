#!/bin/sh

# Create password if DB not initialized
if [ -f "/config/postgres/PG_VERSION" ]; then
  echo "DB exisit"
  else
    # Generate a random password for PostgreSQL
    echo "Creating db password"
    export POSTGRES_PASSWORD=$(pwgen -s 16 1)
    echo -e "\npostgresql-password: $POSTGRES_PASSWORD" >> /app/guacamole/guacamole.properties
fi

echo "Running startup scripts"
/usr/local/bin/_startup.sh

echo "Init DB Check"
/usr/local/bin/_postgres.sh postgres &

echo "Post startup DB scripts"
gosu postgres bash -c '/usr/local/bin/_post_startup.sh'

echo "DB Preparation finished exiting for main processes..."
gosu postgres /bin/sh -c 'pg_ctl -D "$PGDATA" -m fast -w stop'

exec /usr/bin/supervisord -c /etc/supervisord.conf