#!/usr/bin/env bash

echo "Running startup scripts"
/usr/local/bin/_startup.sh

echo "Running Guacamole server"
/etc/init.d/guacd start

echo "Running Tomcat"
/etc/init.d/tomcat start

echo "Running Postgres"
/etc/init.d/postgres start

echo "Post Startup scripts"
gosu postgres bash -c '/usr/local/bin/_post_startup.sh'

echo "container started"
tail -f /dev/null