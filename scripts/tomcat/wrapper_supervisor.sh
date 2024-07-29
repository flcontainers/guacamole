#!/bin/sh

function shutdown()
{
    date
    echo "Shutting down Tomcat"
    unset CATALINA_PID # Necessary in some cases
    unset LD_LIBRARY_PATH # Necessary in some cases
    unset JAVA_OPTS # Necessary in some cases

    $CATALINA_HOME/bin/catalina.sh stop
}

date
echo "Starting Tomcat"

. $CATALINA_HOME/bin/catalina.sh start

# Allow any signal which would kill a process to stop Tomcat
trap shutdown HUP INT QUIT ABRT KILL ALRM TERM TSTP SIGTERM SIGINT

echo "Waiting for `cat $CATALINA_PID`"
wait `cat $CATALINA_PID`