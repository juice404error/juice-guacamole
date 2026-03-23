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
COPY --from=client /opt/guacamole /opt/guacamole

RUN cp /opt/guacamole/webapp/guacamole.war /opt/guacamole/guacamole.war && \
    cp -r /opt/guacamole/extensions/guacamole-auth-jdbc/mysql/ /opt/guacamole/mysql/
    #rm -rf /opt/guacamole_client

# Tomcat telepítés
RUN set -x && \
    TOMCAT_9_VER=$(curl -s https://archive.apache.org/dist/tomcat/tomcat-9/ | grep -oE 'v9\.0\.[0-9]+' | sort -V | tail -n 1 | sed 's/^v//') && \
    curl -L "https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_9_VER}/bin/apache-tomcat-${TOMCAT_9_VER}.tar.gz" | \
    tar -xzC ${CATALINA_HOME} --strip-components=1 && \
    #rm -rf ${CATALINA_HOME}/webapps/* && \
    ln -s ${CATALINA_HOME}/webapps ${CATALINA_BASE}/webapps && \
    ln -s ${CATALINA_HOME}/conf ${CATALINA_BASE}/conf

RUN adduser -h /config -s /bin/sh -u 99 -D abc && \
    adduser -h /opt/tomcat -s /bin/false -D tomcat && \
    mkdir -p /config/guacamole/extensions /config/log/tomcat /var/run/tomcat /var/run/mysqld

COPY ./image/etc/ /etc/
COPY ./image-mariadb/etc/ /etc/

### ENTRYPOINT SCRIPT JAVÍTÁSA
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo 'PUID=${PUID:-1000}' >> /entrypoint.sh && \
    echo 'PGID=${PGID:-100}' >> /entrypoint.sh && \
    # Fixáljuk a csoportot: az abc csoportot a PGID-hez rendeljük
    echo 'groupmod -o -g "$PGID" abc || true' >> /entrypoint.sh && \
    echo 'usermod -o -u "$PUID" abc' >> /entrypoint.sh && \
    # Először létrehozzuk a fizikai mappákat a /config alatt
    echo 'mkdir -p /config/guacamole/extensions /config/guacamole/lib /config/log/tomcat /config/log/mysql /config/mysql-schema /config/databases' >> /entrypoint.sh && \
    # Létrehozzuk a futáshoz szükséges belső mappákat (ha linkek voltak, töröljük és mappává tesszük őket a stabilitásért)
    echo 'for dir in work temp logs; do [ -L /var/lib/tomcat/$dir ] && rm /var/lib/tomcat/$dir; mkdir -p /var/lib/tomcat/$dir; done' >> /entrypoint.sh && \
    echo 'mkdir -p /var/run/mysqld /var/run/tomcat' >> /entrypoint.sh && \
    # Script takarítás (Windows-os sorvégek ellen)
    echo 'chmod +x /etc/firstrun/*.sh' >> /entrypoint.sh && \
    echo 'find /etc/firstrun/ -name "*.sh" -exec sed -i "s/\\r$//" {} +' >> /entrypoint.sh && \
    # Jogosultságok: Az abc:abc itt már működni fog, mert feljebb fixáltuk a csoportot
    echo 'chown -R abc:abc /config /var/run/mysqld /var/run/tomcat /opt/tomcat /var/lib/tomcat /etc/firstrun' >> /entrypoint.sh && \
    # A kritikus temp és work mappáknak 755-ös jogot adunk (mint Jason-nél), nem 777-et, hogy a Java ne panaszkodjon
    echo 'chmod -R 755 /var/lib/tomcat/work /var/lib/tomcat/temp /var/lib/tomcat/logs' >> /entrypoint.sh && \
    # Itt jön be a TINI használata az indításhoz!
    echo 'exec /sbin/tini -- /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

RUN set -x && \
    ln -s /opt/guacamole/guacamole.war ${CATALINA_BASE}/webapps/ROOT.war && \
    ln -s /config/log/tomcat /var/lib/tomcat/logs && \
    chmod +x /opt/guacamole/sbin/guacd

EXPOSE 8080
VOLUME ["/config"]
ENTRYPOINT ["/entrypoint.sh"]
