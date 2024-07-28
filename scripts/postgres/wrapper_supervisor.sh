#!/bin/sh

function shutdown()
{
    date
    echo "Shutting down Postgresql"

    gosu postgres /bin/sh -c 'pg_ctl -D "$PGDATA" -m fast -w stop'

}

date
echo "Starting Postgresql"
gosu postgres /usr/bin/postgres


# Allow any signal which would kill a process to stop GUACD
trap shutdown HUP INT QUIT ABRT KILL ALRM TERM TSTP

echo "Waiting for `cat $POSTGRES_PID`"
wait `cat $POSTGRES_PID`