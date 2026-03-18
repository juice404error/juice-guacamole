ARG GUAC_VER=1.5.5

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

### Környezeti változók a Jasonbean struktúra szerint
ENV GUACAMOLE_HOME=/config/guacamole \
    CATALINA_HOME=/opt/tomcat \
    CATALINA_BASE=/var/lib/tomcat \
    LD_LIBRARY_PATH=/opt/guacamole/lib \
    GUACD_LOG_LEVEL=info \
    LOGBACK_LEVEL=info \
    JAVA_HOME=/usr/lib/jvm/default-jvm

### Binárisok átmásolása a hivatalos image-ekből
COPY --from=server /opt/guacamole /opt/guacamole
COPY --from=client /opt/guacamole /opt/guacamole

### Függőségek telepítése (Alpine 3.19 kompatibilis lista)
RUN apk update && apk add --no-cache \
    bash curl shadow supervisor tzdata unzip \
    mariadb mariadb-client mysql-client \
    openjdk11-jre-headless \
    cairo libjpeg-turbo libpng pango uuid-dev \
    ghostscript terminus-font ttf-dejavu ttf-liberation \
    util-linux-login procps logrotate pwgen netcat-openbsd

### Tomcat 9 telepítése
RUN mkdir -p ${CATALINA_HOME} ${CATALINA_BASE} && \
    curl -L https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.86/bin/apache-tomcat-9.0.86.tar.gz | \
    tar -xzC ${CATALINA_HOME} --strip-components=1 && \
    rm -rf ${CATALINA_HOME}/webapps/* && \
    ln -s ${CATALINA_HOME}/webapps ${CATALINA_BASE}/webapps && \
    ln -s ${CATALINA_HOME}/conf ${CATALINA_BASE}/conf

### Mappaszerkezet és jogosultságok előkészítése
RUN groupmod -g 1001 users && \
    useradd -u 1000 -U -d /config -s /bin/false abc && \
    usermod -G users abc && \
    mkdir -p /config/guacamole /config/log/tomcat /var/run/tomcat /var/run/mysqld /var/lib/tomcat/temp && \
    ln -s /opt/guacamole/guacamole.war ${CATALINA_BASE}/webapps/guacamole.war

### Fájlok másolása a repóból (etc mappa)
COPY image/ /
# Ha a forkodban az 'image' mappa tartalmazza a fájlokat, akkor 'COPY image/ /'
# Ha a 'root' mappába tetted őket, akkor 'COPY root/ /'
# A jasonbean-nél ez általában az 'image' mappa.

### Jogosultságok és sorvégek kényszerített javítása
RUN chmod +x /etc/firstrun/*.sh && \
    sed -i 's/\r$//' /etc/firstrun/*.sh && \
    chown -R abc:abc /opt/guacamole /config ${CATALINA_HOME} ${CATALINA_BASE} /var/run/mysqld

EXPOSE 8080
VOLUME ["/config"]

ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
