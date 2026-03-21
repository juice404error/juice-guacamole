#!/bin/bash
echo "--- Initializing Guacamole Environment ---"

# 1. User szinkronizálás (hogy ne 99 legyen)
PUID=${PUID:-1000}
PGID=${PGID:-100}

groupmod -o -g "$PGID" abc
usermod -o -u "$PUID" abc

# 2. Sablonok és logback.xml (Visszaállítva a korábbi jó logika)
mkdir -p /config/guacamole
if [ ! -f "/config/guacamole/guacamole.properties" ]; then
    echo "Creating properties from template..."
    cp /etc/firstrun/templates/* /config/guacamole/
fi

if [ ! -f "/config/guacamole/logback.xml" ]; then
    echo "Extracting logback.xml from WAR..."
    unzip -o -j /opt/guacamole/guacamole.war "WEB-INF/classes/logback.xml" -d "/config/guacamole/" > /dev/null 2>&1
fi

# 3. MySQL Sémák szinkronizálása
if [ "$OPT_MYSQL" = "Y" ]; then
    echo "Syncing MySQL schemas..."
    mkdir -p /config/mysql-schema
    cp -R /opt/guacamole/mysql/schema/* /config/mysql-schema/
    mkdir -p /config/guacamole/extensions
    cp /opt/guacamole/mysql/*.jar /config/guacamole/extensions/
fi

# 4. Jogosultságok - CSAK a szükséges helyeken, de ott alaposan
chown -R abc:users /config/guacamole /config/mysql-schema /opt/tomcat /var/run/tomcat
echo "--- Initialization Finished ---"
