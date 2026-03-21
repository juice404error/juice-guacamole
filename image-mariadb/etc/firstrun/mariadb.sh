#!/bin/bash
MYSQL_DATABASE="/config/databases"
MYSQL_SCHEMA="/config/mysql-schema"
SOCKET="/var/run/mysqld/mysqld.sock"
MYSQL_CONFIG="/etc/my.cnf.d/mariadb-server.cnf"
PUID=${PUID:-1000}

echo "[$(date)] Starting MariaDB wrapper (PUID: $PUID)..."

# 1. Konfig injektálás pontosan Jason mintájára
if ! grep -q "user=" "$MYSQL_CONFIG"; then
    echo "[$(date)] Injecting user= $PUID into MariaDB config..."
    sed -i "/\[mysqld\]/a user= $PUID" "$MYSQL_CONFIG"
fi

# 2. Mappák létrehozása és 777-es jogosultság az inicializálásig
mkdir -p "$MYSQL_DATABASE" /var/run/mysqld /var/log/mysql
if [ ! -f "$MYSQL_DATABASE/guacamole/version" ]; then
    echo "[$(date)] Cleaning database directory content for fresh install..."
    find "$MYSQL_DATABASE" -mindepth 1 -delete
fi

# Átmeneti 777, hogy a MariaDB belső folyamatai ne akadjanak el
chown -R root:root /var/run/mysqld /var/log/mysql "$MYSQL_DATABASE"
chmod -R 777 /var/run/mysqld /var/log/mysql "$MYSQL_DATABASE"

# 3. Inicializálás
if [ ! -d "$MYSQL_DATABASE/mysql" ]; then
    echo "[$(date)] Initializing MariaDB structure..."
    mysql_install_db --user=root --datadir="$MYSQL_DATABASE" --skip-test-db --auth-root-authentication-method=normal > /dev/null 2>&1
    
    /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --user=root &
    TEMP_PID=$!
    
    echo "[$(date)] Waiting for database to be ready..."
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
        echo "[$(date)] ERROR: Database failed to start. Check /config/databases/mysql_safe.log"
        exit 1
    fi
fi

# 4. VÉGLEGES ÁTADÁS: Minden a juice-é (1000)
echo "[$(date)] Finalizing permissions for abc user..."
chown -R abc:users "$MYSQL_DATABASE" /var/run/mysqld /var/log/mysql
chmod -R 755 "$MYSQL_DATABASE"
exec /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --user=abc
