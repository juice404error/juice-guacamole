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
    JAVA_HOME=/usr/lib/jvm/default-jvm \
    HOME=/config

### Függőségek telepítése
RUN apk update && apk add --no-cache \
    bash curl shadow supervisor tzdata unzip \
    mariadb mariadb-client mysql-client \
    openjdk11-jre-headless \
    cairo libjpeg-turbo libpng pango \
    libuuid util-linux-dev \
    ghostscript terminus-font ttf-dejavu ttf-liberation \
    util-linux-login procps logrotate pwgen netcat-openbsd \
    tini

### Alap struktúra létrehozása
RUN mkdir -p /etc/firstrun /etc/supervisor/conf.d /etc/my.cnf.d \
             /opt/tomcat /var/lib/tomcat

### Binárisok átmásolása - A TELJES MAPPÁKAT HOZZUK ÁT
COPY --from=server /opt/guacamole /opt/guacamole
COPY --from=client /opt/guacamole /opt/guacamole_client

# A kliensből a szükséges fájlok áthelyezése
RUN cp /opt/guacamole_client/webapp/guacamole.war /opt/guacamole/guacamole.war && \
    cp -r /opt/guacamole_client/extensions/guacamole-auth-jdbc/mysql/ /opt/guacamole/mysql/ && \
    rm -rf /opt/guacamole_client

### Tomcat 9 telepítése
RUN set -x && \
    TOMCAT_9_VER=$(curl -s https://archive.apache.org/dist/tomcat/tomcat-9/ | grep -oE 'v9\.0\.[0-9]+' | sort -V | tail -n 1 | sed 's/^v//') && \
    curl -L "https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_9_VER}/bin/apache-tomcat-${TOMCAT_9_VER}.tar.gz" | \
    tar -xzC ${CATALINA_HOME} --strip-components=1 && \
    rm -rf ${CATALINA_HOME}/webapps/* && \
    ln -s ${CATALINA_HOME}/webapps ${CATALINA_BASE}/webapps && \
    ln -s ${CATALINA_HOME}/conf ${CATALINA_BASE}/conf

### FELHASZNÁLÓ LÉTREHOZÁSA (UID 99, /bin/sh shell)
RUN adduser -h /config -s /bin/sh -u 99 -G users -D abc && \
    adduser -h /opt/tomcat -s /bin/false -D tomcat && \
    mkdir -p /config/guacamole/extensions /config/log/tomcat /var/run/tomcat /var/run/mysqld /var/lib/tomcat/temp /var/log/supervisor

### Saját konfigurációs fájlok másolása
COPY ./image/etc/ /etc/
COPY ./image-mariadb/etc/ /etc/

### Entrypoint wrapper - JAVÍTOTT JOGOSULTSÁGOK
# A titok: a /opt/guacamole maradjon ROOT tulajdonban, ahogy Jasonbean-nél!
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'mkdir -p /config/guacamole/extensions /config/guacamole/lib /config/log/tomcat /config/log/mysql /var/run/mysqld /var/run/tomcat' >> /entrypoint.sh && \
    echo 'chmod 755 /bin /lib /sbin /usr /usr/bin /usr/lib /etc' >> /entrypoint.sh && \
    echo 'chmod 755 /opt/guacamole /opt/guacamole/sbin /opt/guacamole/sbin/guacd' >> /entrypoint.sh && \
    echo 'chmod +x /etc/firstrun/*.sh' >> /entrypoint.sh && \
    echo 'sed -i "s/\r$//" /etc/firstrun/*.sh' >> /entrypoint.sh && \
    # CSAK a VOLUME-ot és az írható mappákat adjuk át az abc-nek
    echo 'chown -R abc:users /config /var/run/mysqld /var/run/tomcat /opt/tomcat /etc/firstrun' >> /entrypoint.sh && \
    # A /opt/guacamole-t KIFEJEZETTEN root-ként tartjuk meg
    echo 'chown -R root:root /opt/guacamole' >> /entrypoint.sh && \
    echo 'exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

### Utómunka: Végső simítások a build során
RUN set -x && \
    ln -sf /opt/guacamole/guacamole.war ${CATALINA_BASE}/webapps/guacamole.war && \
    chmod +x /opt/guacamole/sbin/guacd && \
    find /etc/firstrun/ -name "*.sh" -exec sed -i 's/\r$//' {} + && \
    find /etc/firstrun/ -name "*.sh" -exec chmod +x {} + && \
    chmod -R 644 /etc/supervisor/conf.d/* && \
    # FIX: A /opt/guacamole és a /var/lib/tomcat/conf maradjon root, 
    # de a többi írható hely legyen az abc-é
    chown -R root:root /opt/guacamole /etc/supervisor && \
    chown -R abc:users /config ${CATALINA_HOME} ${CATALINA_BASE} /var/run/mysqld /etc/firstrun /etc/my.cnf.d

EXPOSE 8080
VOLUME ["/config"]

ENTRYPOINT ["/entrypoint.sh"]
