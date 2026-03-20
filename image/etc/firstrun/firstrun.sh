#!/bin/bash

# Alapértelmezett útvonalak
GUAC_EXT="/config/guacamole/extensions"
MYSQL_JAR_SRC="/opt/guacamole/mysql/guacamole-auth-jdbc-mysql.jar"

echo "--- Initializing Guacamole Environment ---"

# Jogosultságok beállítása a helyes csoporttal (abc:users)
chown -R abc:users /config ${CATALINA_BASE} /var/run/tomcat /var/run/mysqld

# Hiányzó konfigurációs fájlok másolása a sablonokból
if [ ! -f "$GUACAMOLE_HOME"/guacamole.properties ]; then
    echo "Copying default configuration files from templates..."
    mkdir -p "$GUACAMOLE_HOME"
    cp /etc/firstrun/templates/guacamole.properties "$GUACAMOLE_HOME"/
    cp /etc/firstrun/templates/user-mapping.xml "$GUACAMOLE_HOME"/
    # Ha van logback template-ed, azt is ide teheted, vagy marad az unzip
fi

# Logback.xml kinyerése, ha nem létezik
if [ ! -f "$GUACAMOLE_HOME"/logback.xml ]; then
    echo "Extracting default logback.xml..."
    unzip -o -j /opt/guacamole/guacamole.war WEB-INF/classes/logback.xml -d "$GUACAMOLE_HOME" > /dev/null
fi

# Log szint beállítása
if [ -f "$GUACAMOLE_HOME"/logback.xml ]; then
    sed -i "s/level=\"[^\"]*\"/level=\"$LOGBACK_LEVEL\"/" "$GUACAMOLE_HOME"/logback.xml
fi

# MySQL Extension kezelése
mkdir -p "$GUAC_EXT"
if [ ! -f "$GUAC_EXT/$(basename $MYSQL_JAR_SRC)" ]; then
    echo "Installing MySQL extension..."
    cp "$MYSQL_JAR_SRC" "$GUAC_EXT/"
fi

# Végső jogosultság ellenőrzés a mappán
chown -R abc:users "$GUACAMOLE_HOME"

echo "--- Initialization Finished ---"
