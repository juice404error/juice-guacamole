#!/bin/bash
echo "--- Initializing Guacamole Environment ---"

mkdir -p /config/guacamole/extensions /config/guacamole/lib /config/log/tomcat /config/mysql-schema

if [ ! -f "/config/guacamole/guacamole.properties" ]; then
    echo "Creating properties from template..."
    cp /etc/firstrun/templates/* /config/guacamole/
fi

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

sed -i 's/ level="[^"]*"/ level="'$LOGBACK_LEVEL'"/' /config/guacamole/logback.xml

if [ "$OPT_MYSQL" = "Y" ]; then
    echo "Syncing MySQL extensions and JDBC driver..."
    # A sémákat mindig felülírjuk az aktuálisra a konténerből
    cp -R /opt/guacamole/mysql/schema/* /config/mysql-schema/
    # Az extension-öket és a libeket is szinkronizáljuk
    cp /opt/guacamole/mysql/*.jar /config/guacamole/extensions/
    cp /opt/guacamole/mysql/lib/*.jar /config/guacamole/lib/ 2>/dev/null
    
    chmod +x /config/guacamole/extensions/*.jar
    chmod +x /config/guacamole/lib/*.jar 2>/dev/null
fi

chown -R abc:abc /config/guacamole /config/mysql-schema /config/log/tomcat
echo "--- Initialization Finished ---"
