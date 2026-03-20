#!/bin/bash
echo "--- Initializing Guacamole Environment ---"

# Sablonok másolása
if [ ! -f "/config/guacamole/guacamole.properties" ]; then
    echo "Creating properties from template..."
    cp /etc/firstrun/templates/* /config/guacamole/
fi

# Logback.xml kinyerése (bármilyen belső útvonalon is van)
if [ ! -f "/config/guacamole/logback.xml" ]; then
    echo "Extracting logback.xml..."
    cd /config/guacamole && unzip -o -j /opt/guacamole/guacamole.war "*logback.xml" > /dev/null
    cd /
fi

# MySQL Sémák szinkronizálása a láthatóságért
if [ "$OPT_MYSQL" = "Y" ]; then
    echo "Syncing MySQL schemas..."
    cp -R /opt/guacamole/mysql/schema/* /config/mysql-schema/
    mkdir -p /config/guacamole/extensions
    cp /opt/guacamole/mysql/*.jar /config/guacamole/extensions/
fi

# Biztonsági jogosultság fix az újonnan másolt fájlokra
chown -R abc:users /config/guacamole /config/mysql-schema

echo "--- Initialization Finished ---"
