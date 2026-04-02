# 1. SZAKASZ: Argumentum definiálása a globális hatókörben
ARG GUAC_VER=1.6.0

# Kliens forrás kinyerése
FROM guacamole/guacamole:${GUAC_VER} AS client-source

# 2. SZAKASZ: Végleges Image
FROM alpine:edge

# KRITIKUS: Újra kell deklarálni az ARG-ot a FROM után, 
# hogy ebben a szakaszban is elérhető legyen!
ARG GUAC_VER

ENV GUACAMOLE_HOME=/config/guacamole \
    CATALINA_HOME=/opt/tomcat \
    CATALINA_BASE=/var/lib/tomcat \
    LD_LIBRARY_PATH=/usr/lib \
    GUACD_LOG_LEVEL=info \
    LOGBACK_LEVEL=info \
    JAVA_HOME=/usr/lib/jvm/default-jvm \
    HOME=/config

# Csomagok + Guacamole Server (OpenSSL 3 kompatibilis)
RUN apk update && apk add --no-cache \
    bash curl shadow supervisor tzdata unzip \
    mariadb mariadb-client mysql-client \
    openjdk11-jre-headless cairo libjpeg-turbo libpng pango \
    libuuid util-linux-dev ghostscript terminus-font \
    ttf-dejavu ttf-liberation util-linux-login procps \
    logrotate pwgen netcat-openbsd tini openssl \
    guacamole-server \
    guacamole-server-rdp \
    guacamole-server-vnc \
    guacamole-server-ssh

RUN mkdir -p /etc/firstrun /etc/supervisor/conf.d /etc/my.cnf.d /opt/tomcat /var/lib/tomcat

# Kliens fájlok átemelése a build során
COPY --from=client-source /opt/guacamole/ /opt/guacamole/

# Tomcat és MySQL Driver telepítése
RUN TOMCAT_9_VER=$(curl -s https://archive.apache.org/dist/tomcat/tomcat-9/ | grep -oE 'v9\.0\.[0-9]+' | sort -V | tail -n 1 | sed 's/^v//') && \
    curl -L "https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_9_VER}/bin/apache-tomcat-${TOMCAT_9_VER}.tar.gz" | tar -xzC ${CATALINA_HOME} --strip-components=1 && \
    rm -rf ${CATALINA_HOME}/webapps/* && \
    mkdir -p /var/lib/tomcat/webapps /var/lib/tomcat/temp /var/lib/tomcat/work && \
    ln -s /opt/tomcat/conf /var/lib/tomcat/conf && \
    LATEST_DRIVER_VER=$(curl -s "https://search.maven.org/solrsearch/select?q=g:com.mysql+AND+a:mysql-connector-j" | grep -oE '"latestVersion":"[^"]+"' | head -1 | cut -d'"' -f4) && \
    mkdir -p /opt/guacamole/mysql/lib && \
    curl -fL -o /opt/guacamole/mysql/lib/mysql-connector-j.jar "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${LATEST_DRIVER_VER}/mysql-connector-j-${LATEST_DRIVER_VER}.jar"

# Felhasználók és könyvtárak
RUN adduser -h /config -s /bin/sh -u 99 -D abc && \
    adduser -h /opt/tomcat -s /bin/false -D tomcat && \
    mkdir -p /config/guacamole/extensions /config/guacamole/lib /config/log/tomcat /var/run/tomcat /var/run/mysqld

# Egyéb konfigurációk másolása
COPY ./image/etc/ /etc/
COPY ./image-mariadb/etc/ /etc/

# ENTRYPOINT GENERÁLÁSA
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'PUID=${PUID:-1000}' >> /entrypoint.sh && \
    echo 'PGID=${PGID:-100}' >> /entrypoint.sh && \
    echo 'groupmod -o -g "$PGID" abc || true' >> /entrypoint.sh && \
    echo 'usermod -o -u "$PUID" abc' >> /entrypoint.sh && \
    # Könyvtárak biztosítása
    echo 'mkdir -p /config/guacamole/extensions /config/guacamole/lib /config/log/tomcat /config/log/mysql /config/mysql-schema/upgrade /config/databases' >> /entrypoint.sh && \
    echo 'mkdir -p /var/run/mysqld /var/run/tomcat /var/lib/tomcat/work /var/lib/tomcat/temp /var/lib/tomcat/logs /var/lib/tomcat/webapps /opt/guacamole/sbin' >> /entrypoint.sh && \
    # 1. FIX: Sémák átmásolása (hogy a mariadb.sh megtalálja őket)
    echo 'if [ -d "/opt/guacamole/mysql/schema" ]; then cp -r /opt/guacamole/mysql/schema/* /config/mysql-schema/; fi' >> /entrypoint.sh && \
    # 2. FIX: Pluginok linkelése (hogy a guacd lássa az RDP/SSH/VNC-t)
    echo 'mkdir -p /usr/lib/guacamole' >> /entrypoint.sh && \
    echo 'ln -sf /usr/lib/libguac-client-*.so* /usr/lib/guacamole/' >> /entrypoint.sh && \
    # Tomcat webapp beállítása
    echo 'rm -rf /var/lib/tomcat/webapps/ROOT /var/lib/tomcat/webapps/ROOT.war' >> /entrypoint.sh && \
    echo 'ln -sf /opt/guacamole/guacamole.war /var/lib/tomcat/webapps/ROOT.war' >> /entrypoint.sh && \
    # Szkript tisztítás és jogosultságok
    echo 'chmod +x /etc/firstrun/*.sh' >> /entrypoint.sh && \
    echo 'find /etc/firstrun/ -name "*.sh" -exec sed -i "s/\\r$//" {} +' >> /entrypoint.sh && \
    echo 'chown -R abc:abc /config /var/run/mysqld /var/run/tomcat /opt/tomcat /var/lib/tomcat /etc/firstrun' >> /entrypoint.sh && \
    echo 'chmod -R 755 /var/lib/tomcat/work /var/lib/tomcat/temp /var/lib/tomcat/logs /var/lib/tomcat/webapps' >> /entrypoint.sh && \
    # Kompatibilitási link a guacd-nek
    echo 'ln -sf /usr/sbin/guacd /opt/guacamole/sbin/guacd' >> /entrypoint.sh && \
    echo 'exec /sbin/tini -- /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

EXPOSE 8080
VOLUME ["/config"]
ENTRYPOINT ["/entrypoint.sh"]
