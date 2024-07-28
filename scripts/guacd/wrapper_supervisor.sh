#!/bin/sh

function shutdown()
{
    date
    echo "Shutting down Guacd"

}

date
echo "Starting Guacd"

/opt/guacamole/sbin/guacd -b 0.0.0.0 -L $GUACD_LOG_LEVEL -f

sleep 5

# Allow any signal which would kill a process to stop GUACD
trap shutdown HUP INT QUIT ABRT KILL ALRM TERM TSTP SIGTERM SIGINT

echo "Waiting for `pgrep -f guacd`"
wait `pgrep -f guacd`