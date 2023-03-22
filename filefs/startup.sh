#!/usr/bin/env bash

echo "Running startup scripts"
/usr/local/bin/_startup.sh

echo "Running Postgres"
/etc/init.d/postgres start

echo "Running Guacamole server"
/etc/init.d/guacd start

echo "Post startup DB scripts"
gosu postgres bash -c '/usr/local/bin/_post_startup.sh'

echo "Running Tomcat"
# Wait for postgres to be ready
while ! nc -z localhost 5432; do   
  sleep 5
done
/etc/init.d/tomcat start

echo "container started"
tail -f /dev/null