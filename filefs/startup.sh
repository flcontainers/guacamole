#!/bin/sh

echo "Running startup scripts"
/usr/local/bin/_startup.sh

echo "Running Postgres"
/etc/init.d/postgres start

echo "Running Guacamole server"
bash -c '/opt/guacamole/sbin/guacd -b 0.0.0.0 -L $GUACD_LOG_LEVEL -f' &

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