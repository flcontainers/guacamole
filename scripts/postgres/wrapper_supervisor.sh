#!/bin/sh

function shutdown()
{
    date
    echo "Shutting down Postgresql"

    pg_ctl -m fast -w stop

}

date
echo "Starting Postgresql"

postgres

sleep 5

# Allow any signal which would kill a process to stop Postgres
trap shutdown HUP INT QUIT ABRT KILL ALRM TERM TSTP SIGTERM SIGINT

echo "Waiting for `head -1 $POSTGRES_PID`"
wait `cat $POSTGRES_PID`