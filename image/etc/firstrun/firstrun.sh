#!/bin/bash
echo "--- Initializing Guacamole Environment ---"

# 1. User beállítása - Kényszerítjük a 1000-es ID-t, ha nem jönne környezeti változó
PUID=${PUID:-1000}
PGID=${PGID:-100}

groupmod -o -g "$PGID" abc
usermod -o -u "$PUID" abc

echo "----------------------"
echo "User UID: $(id -u abc)"
echo "User GID: $(id -g abc)"
echo "----------------------"

# Sablonok másolása
if [ ! -f "/config/guacamole/guacamole.properties" ]; then
    echo "Creating properties from template..."
    mkdir -p /config/guacamole
    cp /etc/firstrun/templates/* /config/guacamole/
fi

# Logback.xml kinyerése
if [ ! -f "/config/guacamole/logback.xml" ]; then
    echo "Extracting logback.xml..."
    unzip -o -j /opt/guacamole/guacamole.war "WEB-INF/classes/logback.xml" -d "/config/guacamole/" > /dev/null 2>&1
fi

# MySQL Sémák szinkronizálása
if [ "$OPT_MYSQL" = "Y" ]; then
    echo "Syncing MySQL schemas..."
    mkdir -p /config/mysql-schema
    cp -R /opt/guacamole/mysql/schema/* /config/mysql-schema/
    mkdir -p /config/guacamole/extensions
    cp /opt/guacamole/mysql/*.jar /config/guacamole/extensions/
fi

# CSAK a specifikus mappákat írjuk át, nem a teljes /config-ot!
chown -R abc:users /config/guacamole /config/mysql-schema /opt/tomcat /var/run/tomcat
echo "--- Initialization Finished ---"
