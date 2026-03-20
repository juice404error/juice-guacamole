#!/bin/bash

# Alapértelmezett útvonalak
GUAC_EXT="/config/guacamole/extensions"
MYSQL_JAR_SRC="/opt/guacamole/mysql/guacamole-auth-jdbc-mysql.jar"

echo "--- Initializing Guacamole Environment ---"

# Jogosultságok ellenőrzése
chown -R abc:abc /config ${CATALINA_BASE} /var/run/tomcat /var/run/mysqld

# Logback.xml kinyerése, ha nem létezik
if [ ! -f "$GUACAMOLE_HOME"/logback.xml ]; then
    echo "Extracting default logback.xml..."
    unzip -o -j /opt/guacamole/guacamole.war WEB-INF/classes/logback.xml -d "$GUACAMOLE_HOME" > /dev/null
fi

# Log szint beállítása
sed -i "s/level=\"[^\"]*\"/level=\"$LOGBACK_LEVEL\"/" "$GUACAMOLE_HOME"/logback.xml

# MySQL Extension kezelése (csak ha OPT_MYSQL=Y)
if [ "$OPT_MYSQL" = "Y" ]; then
    mkdir -p "$GUAC_EXT"
    # Csak akkor másolunk, ha a forrás frissebb vagy nem létezik a cél
    if [ ! -f "$GUAC_EXT/$(basename $MYSQL_JAR_SRC)" ]; then
        echo "Installing/Updating MySQL extension..."
        cp "$MYSQL_JAR_SRC" "$GUAC_EXT/"
    fi
fi

echo "--- Initialization Finished ---"
