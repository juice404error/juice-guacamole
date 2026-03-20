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
    cairo libjpeg-turbo libpng pango uuid-dev \
    ghostscript terminus-font ttf-dejavu ttf-liberation \
    util-linux-login procps logrotate pwgen netcat-openbsd

### Struktúra létrehozása
RUN mkdir -p /opt/guacamole/mysql /opt/guacamole/sbin /opt/guacamole/lib /etc/firstrun /etc/supervisor/conf.d

### Binárisok átmásolása az új 1.6.0 struktúra szerint
COPY --from=server /opt/guacamole/sbin/guacd /opt/guacamole/sbin/guacd
COPY --from=server /opt/guacamole/lib/ /opt/guacamole/lib/
COPY --from=client /opt/guacamole/webapp/guacamole.war /opt/guacamole/guacamole.war
COPY --from=client /opt/guacamole/extensions/guacamole-auth-jdbc/mysql/ /opt/guacamole/mysql/

### Tomcat 9 dinamikus letöltése
RUN set -x && \
    TOMCAT_9_VER=$(curl -s https://archive.apache.org/dist/tomcat/tomcat-9/ | grep -oE 'v9\.0\.[0-9]+' | sort -V | tail -n 1 | sed 's/^v//') && \
    echo "Detected Tomcat version: ${TOMCAT_9_VER}" && \
    mkdir -p ${CATALINA_HOME} ${CATALINA_BASE} && \
    curl -L "https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_9_VER}/bin/apache-tomcat-${TOMCAT_9_VER}.tar.gz" | \
    tar -xzC ${CATALINA_HOME} --strip-components=1 && \
    rm -rf ${CATALINA_HOME}/webapps/* && \
    ln -s ${CATALINA_HOME}/webapps ${CATALINA_BASE}/webapps && \
    ln -s ${CATALINA_HOME}/conf ${CATALINA_BASE}/conf

### Felhasználó és könyvtárak
RUN groupmod -g 1001 users && \
    useradd -u 1000 -U -d /config -s /bin/false abc && \
    usermod -G users abc && \
    mkdir -p /config/guacamole/extensions /config/log/tomcat /var/run/tomcat /var/run/mysqld /var/lib/tomcat/temp && \
    ln -s /opt/guacamole/guacamole.war ${CATALINA_BASE}/webapps/guacamole.war

### Saját fájlok másolása
COPY image/ /
COPY image-mariadb/ /

### Jogosultságok kényszerítése és takarítás
# Itt fixáltuk a sed-et, hogy ne bukjon el, ha a shell nem látja a glob-ot
RUN set -x && \
    find /etc/firstrun/ -name "*.sh" -exec sed -i 's/\r$//' {} + && \
    find /etc/firstrun/ -name "*.sh" -exec chmod +x {} + && \
    chown -R abc:abc /opt/guacamole /config ${CATALINA_HOME} ${CATALINA_BASE} /var/run/mysqld

EXPOSE 8080
VOLUME ["/config"]

ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
