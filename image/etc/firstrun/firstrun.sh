#!/bin/bash
echo "--- Initializing Guacamole Environment ---"

# Könyvtárak kényszerített létrehozása
mkdir -p /config/guacamole/extensions /config/log/tomcat /config/mysql-schema

# Sablonok másolása
if [ ! -f "/config/guacamole/guacamole.properties" ]; then
    echo "Creating properties from template..."
    cp /etc/firstrun/templates/* /config/guacamole/
fi

# Logback.xml kinyerése
if [ ! -f "/config/guacamole/logback.xml" ]; then
    echo "Extracting logback.xml..."
    unzip -o -j /opt/guacamole/guacamole.war "WEB-INF/classes/logback.xml" -d "/config/guacamole/" > /dev/null 2>&1
    
    if [ ! -f "/config/guacamole/logback.xml" ]; then
        echo "Creating default logback.xml..."
        cat <<EOF > /config/guacamole/logback.xml
<configuration>
    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder><pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern></encoder>
    </appender>
    <root level="info"><appender-ref ref="STDOUT" /></root>
</configuration>
EOF
    fi
fi

# MySQL Sémák szinkronizálása
if [ "$OPT_MYSQL" = "Y" ]; then
    echo "Syncing MySQL schemas..."
    cp -R /opt/guacamole/mysql/schema/* /config/mysql-schema/
    cp /opt/guacamole/mysql/*.jar /config/guacamole/extensions/
fi

chown -R abc:users /config/guacamole /config/mysql-schema
echo "--- Initialization Finished ---"
