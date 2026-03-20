#!/bin/bash
echo "Starting Tomcat..."

export CATALINA_OPTS="-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

# Log könyvtár biztosítása
mkdir -p /config/log/tomcat
chown -R abc:abc /config/log/tomcat

# Tomcat indítása (run parancs az előtérben tartja)
exec ${CATALINA_HOME}/bin/catalina.sh run
