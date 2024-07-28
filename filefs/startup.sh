#!/bin/sh

# Create password if DB not initialized
if [ -f "/config/postgres/PG_VERSION" ]; then
  echo "DB exisit"
  # Define the path to the properties file
  PROPERTIES_FILE="/config/guacamole/guacamole.properties"
  # Ensure the file exists
  if [[ ! -f "$PROPERTIES_FILE" ]]; then
    echo "Properties file not found: $PROPERTIES_FILE"
  else
    # Read the postgresql-password value
    POSTGRES_PASSWORD=$(grep -E '^postgresql-password:\s*.*' "$PROPERTIES_FILE" | awk -F': ' '{print $2}' | head -n 1)
    # Check if a password was found
    if [[ -z "$POSTGRES_PASSWORD" ]]; then
      echo "postgresql-password not found in $PROPERTIES_FILE"
    else
      # Export the value as an environment variable
      export POSTGRES_PASSWORD
      echo "postgresql-password found in $PROPERTIES_FILE and exported"
    fi
  fi
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