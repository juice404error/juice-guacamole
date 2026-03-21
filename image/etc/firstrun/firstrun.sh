#!/bin/bash
echo "--- Initializing Guacamole Environment ---"

# Sablonok másolása
if [ ! -f "/config/guacamole/guacamole.properties" ]; then
    echo "Creating properties from template..."
    cp /etc/firstrun/templates/* /config/guacamole/
fi

# Logback.xml kinyerése
if [ ! -f "/config/guacamole/logback.xml" ]; then
    echo "Extracting logback.xml..."
    unzip -o -j /opt/guacamole/guacamole.war "WEB-INF/classes/logback.xml" -d "/config/guacamole/" > /dev/null 2>&1
    
    # Tartalék megoldás, ha az unzip nem sikerülne
    if [ ! -f "/config/guacamole/logback.xml" ]; then
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
    mkdir -p /config/mysql-schema
    cp -R /opt/guacamole/mysql/schema/* /config/mysql-schema/
    mkdir -p /config/guacamole/extensions
    cp /opt/guacamole/mysql/*.jar /config/guacamole/extensions/
fi

# Jogosultságok véglegesítése az abc usernek
chown -R abc:users /config/guacamole /config/mysql-schema
echo "--- Initialization Finished ---"
