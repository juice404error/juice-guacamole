#!/bin/bash
MYSQL_DATABASE="/config/databases"
MYSQL_SCHEMA="/config/mysql-schema"
SOCKET="/var/run/mysqld/mysqld.sock"
MYSQL_CONFIG="/etc/my.cnf.d/mariadb-server.cnf"

echo "[$(date)] Starting MariaDB wrapper as root..."

# 1. Jason-féle konfig módosítás: Pontos szóköz használata (user= 1000)
if ! grep -q "user=" "$MYSQL_CONFIG"; then
    echo "[$(date)] Injecting user= $PUID into MariaDB config..."
    sed -i "/\[mysqld\]/a user= $PUID" "$MYSQL_CONFIG"
fi

# 2. Kényszerített tisztítás - CSAK A TARTALMÁT töröljük, a mappát ne!
if [ ! -f "$MYSQL_DATABASE/guacamole/version" ]; then
    echo "[$(date)] Cleaning database directory content for fresh install..."
    # Létrehozzuk ha nincs, vagy ha van, töröljük a tartalmát
    mkdir -p "$MYSQL_DATABASE"
    find "$MYSQL_DATABASE" -mindepth 1 -delete
fi

# 3. Mappák és socket előkészítése
mkdir -p /var/run/mysqld /var/log/mysql
chown -R abc:users /var/run/mysqld /var/log/mysql "$MYSQL_DATABASE"
chmod -R 777 /var/run/mysqld /var/log/mysql

# 4. Inicializálás
if [ ! -d "$MYSQL_DATABASE/mysql" ]; then
    echo "[$(date)] Initializing MariaDB structure..."
    mysql_install_db --user=abc --datadir="$MYSQL_DATABASE" --skip-test-db --auth-root-authentication-method=normal > /dev/null 2>&1
    
    # Itt is érdemes megadni a usert explicit
    /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --user=abc &
    TEMP_PID=$!
    
    echo "[$(date)] Waiting for database to be ready..."
    # Megvárjuk amíg tényleg válaszol
    COUNT=0
    until mysqladmin -u root status > /dev/null 2>&1 || [ $COUNT -eq 30 ]; do 
        sleep 1
        COUNT=$((COUNT+1))
    done

    if mysqladmin -u root status > /dev/null 2>&1; then
        echo "[$(date)] Database ready, loading schemas..."
        PW=$(grep -m 1 "mysql-password:" /config/guacamole/guacamole.properties | awk '{print $2}')
        
        mysql -e "FLUSH PRIVILEGES; ALTER USER 'root'@'localhost' IDENTIFIED BY ''; CREATE DATABASE IF NOT EXISTS guacamole; CREATE USER IF NOT EXISTS 'guacamole'@'localhost' IDENTIFIED BY '$PW'; GRANT ALL PRIVILEGES ON guacamole.* TO 'guacamole'@'localhost'; FLUSH PRIVILEGES;"
        
        mysql guacamole < "$MYSQL_SCHEMA/001-create-schema.sql"
        mysql guacamole < "$MYSQL_SCHEMA/002-create-admin-user.sql"
        
        mkdir -p "$MYSQL_DATABASE/guacamole"
        echo "1.6.0" > "$MYSQL_DATABASE/guacamole/version"
        
        mysqladmin shutdown
        wait $TEMP_PID
    else
        echo "[$(date)] ERROR: Database failed to start in maintenance mode."
        kill $TEMP_PID 2>/dev/null
        exit 1
    fi
fi

echo "[$(date)] Starting MariaDB normally as abc (ID: $PUID)..."
chown -R abc:users "$MYSQL_DATABASE" /var/run/mysqld
exec /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --user=abc
