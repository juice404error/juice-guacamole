#!/bin/bash
function shutdown()
{
    date
    echo "Shutting down Tomcat"
    unset CATALINA_PID # Necessary in some cases
    $CATALINA_HOME/bin/catalina.sh stop
}

date
echo "Starting Tomcat..."
export JAVA_HOME="/usr/lib/jvm/default-jvm"
export CATALINA_HOME="/opt/tomcat"
export CATALINA_BASE="/var/lib/tomcat"
export CATALINA_PID="/var/run/tomcat/tomcat.pid"
export CATALINA_OPTS="-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

# Log könyvtár biztosítása
mkdir -p /config/log/tomcat
chown -R abc:abc /config/log/tomcat

# Tomcat indítása (run parancs az előtérben tartja)
exec ${CATALINA_HOME}/bin/catalina.sh run

trap shutdown HUP INT QUIT ABRT KILL ALRM TERM TSTP

echo "Waiting for `cat $CATALINA_PID`"
wait `cat $CATALINA_PID`
