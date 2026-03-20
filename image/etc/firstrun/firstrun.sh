#!/bin/bash

EXT_STORE="/opt/guacamole"
GUAC_EXT="/config/guacamole/extensions"
MYSQL_JAR_SRC="/opt/guacamole/mysql/guacamole-auth-jdbc-mysql.jar"

echo "--- Initializing Guacamole Environment ---"

# Jogosultságok fixálása (abc:users Alpine-on)
chown -R abc:users /config ${CATALINA_BASE} /var/run/tomcat /var/run/mysqld

# Logback.xml kinyerése
if [ ! -f "$GUACAMOLE_HOME"/logback.xml ]; then
    echo "Extracting logback.xml..."
    mkdir -p "$GUACAMOLE_HOME"
    unzip -o -j /opt/guacamole/guacamole.war WEB-INF/classes/logback.xml -d "$GUACAMOLE_HOME" > /dev/null
fi

# Sablonok kezelése (ha üres a config)
if [ ! -f "$GUACAMOLE_HOME"/guacamole.properties ]; then
    echo "Creating properties from template..."
    cp /etc/firstrun/templates/* /config/guacamole/
    chown -R abc:users /config/guacamole
fi

# MySQL Sémák és kiterjesztés (Ha OPT_MYSQL=Y)
if [ "$OPT_MYSQL" = "Y" ]; then
    echo "Preparing MySQL environment..."
    mkdir -p /config/mysql-schema
    cp -R /opt/guacamole/mysql/schema/* /config/mysql-schema/
    
    mkdir -p "$GUAC_EXT"
    cp "$MYSQL_JAR_SRC" "$GUAC_EXT/"
    
    # Lefuttatjuk az adatbázis initet
    /etc/firstrun/mariadb.sh
    
    echo "Starting Supervisor with MariaDB..."
    exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord-mariadb.conf
else
    echo "Starting standard Supervisor..."
    exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
fi
