ARG GUAC_VER=1.6.0

########################
### Get Guacamole Server
FROM guacamole/guacd:${GUAC_VER} AS server

########################
### Get Guacamole Client
FROM guacamole/guacamole:${GUAC_VER} AS client

####################
### Build Main Image
FROM alpine:3.19
ARG GUAC_VER
LABEL maintainer="Guacamole Modernized"
LABEL version=$GUAC_VER

### Környezeti változók
ENV GUACAMOLE_HOME=/config/guacamole \
    CATALINA_HOME=/opt/tomcat \
    CATALINA_BASE=/var/lib/tomcat \
    LD_LIBRARY_PATH=/opt/guacamole/lib \
    GUACD_LOG_LEVEL=info \
    LOGBACK_LEVEL=info \
    JAVA_HOME=/usr/lib/jvm/default-jvm

### Függőségek telepítése
RUN apk update && apk add --no-cache \
    bash curl shadow supervisor tzdata unzip \
    mariadb mariadb-client mysql-client \
    openjdk11-jre-headless \
    cairo libjpeg-turbo libpng pango \
    libuuid util-linux-dev \
    ghostscript terminus-font ttf-dejavu ttf-liberation \
    util-linux-login procps logrotate pwgen netcat-openbsd

### Alap struktúra létrehozása
RUN mkdir -p /opt/guacamole/mysql /opt/guacamole/sbin /opt/guacamole/lib \
             /etc/firstrun /etc/supervisor/conf.d /etc/my.cnf.d

### Binárisok átmásolása
COPY --from=server /opt/guacamole/sbin/guacd /opt/guacamole/sbin/guacd
COPY --from=server /opt/guacamole/lib/ /opt/guacamole/lib/
COPY --from=client /opt/guacamole/webapp/guacamole.war /opt/guacamole/guacamole.war
COPY --from=client /opt/guacamole/extensions/guacamole-auth-jdbc/mysql/ /opt/guacamole/mysql/

### Tomcat 9 telepítése
RUN set -x && \
    TOMCAT_9_VER=$(curl -s https://archive.apache.org/dist/tomcat/tomcat-9/ | grep -oE 'v9\.0\.[0-9]+' | sort -V | tail -n 1 | sed 's/^v//') && \
    mkdir -p ${CATALINA_HOME} ${CATALINA_BASE} && \
    curl -L "https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_9_VER}/bin/apache-tomcat-${TOMCAT_9_VER}.tar.gz" | \
    tar -xzC ${CATALINA_HOME} --strip-components=1 && \
    rm -rf ${CATALINA_HOME}/webapps/* && \
    ln -s ${CATALINA_HOME}/webapps ${CATALINA_BASE}/webapps && \
    ln -s ${CATALINA_HOME}/conf ${CATALINA_BASE}/conf

### Felhasználó és alkalmazás mappák beállítása
RUN groupmod -g 1001 users && \
    useradd -u 1000 -U -d /config -s /bin/false abc && \
    usermod -G users abc && \
    mkdir -p /config/guacamole/extensions /config/log/tomcat /var/run/tomcat /var/run/mysqld /var/lib/tomcat/temp /var/log/supervisor

### Saját konfigurációs fájlok másolása
COPY ./image/etc/ /etc/
COPY ./image-mariadb/etc/ /etc/

### Entrypoint wrapper - Kényszerített mappa létrehozás és jogosultságok
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    # Mappák létrehozása a VOLUME-on (ha még nem lennének)
    echo 'mkdir -p /config/guacamole/extensions /config/guacamole/lib /config/log/tomcat /var/run/mysqld /var/run/tomcat' >> /entrypoint.sh && \
    # Jogosultságok kényszerítése minden indításkor
    echo 'chown -R abc:abc /config /var/run/mysqld /var/run/tomcat /opt/tomcat' >> /entrypoint.sh && \
    echo 'chmod +x /opt/guacamole/sbin/guacd /etc/firstrun/*.sh' >> /entrypoint.sh && \
    # Supervisor indítása
    echo 'exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

### Utómunka: Binárisok és szkriptek fixálása build közben is
RUN set -x && \
    ln -sf /opt/guacamole/guacamole.war ${CATALINA_BASE}/webapps/guacamole.war && \
    # Minden bináris legyen futtatható
    chmod +x /opt/guacamole/sbin/guacd && \
    if [ -d /etc/firstrun ]; then \
        find /etc/firstrun/ -name "*.sh" -exec sed -i 's/\r$//' {} + && \
        find /etc/firstrun/ -name "*.sh" -exec chmod +x {} +; \
    fi && \
    # Biztonság kedvéért a Supervisor konfigokat is olvashatóvá tesszük
    chmod -R 644 /etc/supervisor/conf.d/* && \
    chown -R abc:abc /opt/guacamole /config ${CATALINA_HOME} ${CATALINA_BASE} /var/run/mysqld /etc/firstrun /etc/my.cnf.d

EXPOSE 8080
VOLUME ["/config"]

ENTRYPOINT ["/entrypoint.sh"]
