ARG GUAC_VER=1.6.0

FROM guacamole/guacd:${GUAC_VER} AS server
FROM guacamole/guacamole:${GUAC_VER} AS client

FROM alpine:3.18
ARG GUAC_VER
ENV GUACAMOLE_HOME=/config/guacamole \
    CATALINA_HOME=/opt/tomcat \
    CATALINA_BASE=/var/lib/tomcat \
    LD_LIBRARY_PATH=/opt/guacamole/lib \
    GUACD_LOG_LEVEL=info \
    LOGBACK_LEVEL=info \
    JAVA_HOME=/usr/lib/jvm/default-jvm \
    HOME=/config

RUN apk update && apk add --no-cache \
    bash curl shadow supervisor tzdata unzip \
    mariadb mariadb-client mysql-client \
    openjdk11-jre-headless cairo libjpeg-turbo libpng pango \
    libuuid util-linux-dev ghostscript terminus-font \
    ttf-dejavu ttf-liberation util-linux-login procps \
    logrotate pwgen netcat-openbsd tini openssl1.1-compat

RUN mkdir -p /etc/firstrun /etc/supervisor/conf.d /etc/my.cnf.d /opt/tomcat /var/lib/tomcat

COPY --from=server /opt/guacamole /opt/guacamole
COPY --from=client /opt/guacamole /opt/guacamole_client

RUN cp /opt/guacamole_client/webapp/guacamole.war /opt/guacamole/guacamole.war && \
    cp -r /opt/guacamole_client/extensions/guacamole-auth-jdbc/mysql/ /opt/guacamole/mysql/ && \
    rm -rf /opt/guacamole_client

# Tomcat telepítés
RUN set -x && \
    TOMCAT_9_VER=$(curl -s https://archive.apache.org/dist/tomcat/tomcat-9/ | grep -oE 'v9\.0\.[0-9]+' | sort -V | tail -n 1 | sed 's/^v//') && \
    curl -L "https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_9_VER}/bin/apache-tomcat-${TOMCAT_9_VER}.tar.gz" | \
    tar -xzC ${CATALINA_HOME} --strip-components=1 && \
    rm -rf ${CATALINA_HOME}/webapps/* && \
    ln -s ${CATALINA_HOME}/webapps ${CATALINA_BASE}/webapps && \
    ln -s ${CATALINA_HOME}/conf ${CATALINA_BASE}/conf

RUN adduser -h /config -s /bin/sh -u 99 -G users -D abc && \
    mkdir -p /config/guacamole/extensions /config/log/tomcat /var/run/tomcat /var/run/mysqld

COPY ./image/etc/ /etc/
COPY ./image-mariadb/etc/ /etc/

### ENTRYPOINT SCRIPT - JAVÍTOTT BIN-LOG ÚTVONALAKKAL ÉS JOGOKKAL
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'PUID=${PUID:-1000}' >> /entrypoint.sh && \
    echo 'PGID=${PGID:-100}' >> /entrypoint.sh && \
    echo 'echo "Initializing system for PUID $PUID..."' >> /entrypoint.sh && \
    echo 'groupmod -o -g "$PGID" users || true' >> /entrypoint.sh && \
    echo 'usermod -o -u "$PUID" abc' >> /entrypoint.sh && \
    echo 'mkdir -p /config/guacamole/extensions /config/guacamole/lib /config/log/tomcat /config/log/mysql /config/mysql-schema /config/databases /var/run/mysqld /var/run/tomcat /var/log/mysql' >> /entrypoint.sh && \
    echo 'chmod +x /etc/firstrun/*.sh' >> /entrypoint.sh && \
    echo 'sed -i "s/\r$//" /etc/firstrun/*.sh' >> /entrypoint.sh && \
    echo 'chown -R abc:users /config /var/run/mysqld /var/run/tomcat /opt/tomcat /etc/firstrun /var/log/mysql' >> /entrypoint.sh && \
    echo 'chmod -R 777 /var/run/mysqld /var/log/mysql' >> /entrypoint.sh && \
    echo 'exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

RUN set -x && \
    ln -sf /opt/guacamole/guacamole.war ${CATALINA_BASE}/webapps/ROOT.war && \
    chmod +x /opt/guacamole/sbin/guacd

EXPOSE 8080
VOLUME ["/config"]
ENTRYPOINT ["/entrypoint.sh"]
