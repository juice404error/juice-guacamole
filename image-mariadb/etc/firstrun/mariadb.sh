#!/bin/bash
MYSQL_DATABASE="/config/databases"
MYSQL_SCHEMA="/config/mysql-schema"
SOCKET="/var/run/mysqld/mysqld.sock"
MYSQL_CONFIG="/etc/my.cnf.d/mariadb-server.cnf"
PUID=${PUID:-1000}

echo "[$(date)] Starting MariaDB wrapper (PUID: $PUID)..."

# 1. Konfig injektálás (pontos szóköz)
if ! grep -q "user=" "$MYSQL_CONFIG"; then
    sed -i "/\[mysqld\]/a user= $PUID" "$MYSQL_CONFIG"
fi

# 2. Mappák kényszerítése és 777-es nyitás
mkdir -p "$MYSQL_DATABASE" /var/run/mysqld /var/log/mysql
# Ez a legfontosabb: amíg nem indul el, root tulajdon és 777
chown -R root:root "$MYSQL_DATABASE" /var/run/mysqld /var/log/mysql
chmod -R 777 "$MYSQL_DATABASE" /var/run/mysqld /var/log/mysql

if [ ! -f "$MYSQL_DATABASE/guacamole/version" ]; then
    echo "[$(date)] Fresh install, cleaning database dir..."
    find "$MYSQL_DATABASE" -mindepth 1 -delete
fi

# 3. Inicializálás
if [ ! -d "$MYSQL_DATABASE/mysql" ]; then
    echo "[$(date)] Initializing MariaDB structure..."
    mysql_install_db --user=root --datadir="$MYSQL_DATABASE" --skip-test-db > /dev/null 2>&1
    
    /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --user=root &
    TEMP_PID=$!
    
    echo "[$(date)] Waiting for database..."
    COUNT=0
    until mysqladmin -u root status > /dev/null 2>&1 || [ $COUNT -eq 30 ]; do sleep 1; COUNT=$((COUNT+1)); done

    if mysqladmin -u root status > /dev/null 2>&1; then
        PW=$(grep -m 1 "mysql-password:" /config/guacamole/guacamole.properties | awk '{print $2}')
        mysql -e "CREATE DATABASE IF NOT EXISTS guacamole; CREATE USER IF NOT EXISTS 'guacamole'@'localhost' IDENTIFIED BY '$PW'; GRANT ALL PRIVILEGES ON guacamole.* TO 'guacamole'@'localhost'; FLUSH PRIVILEGES;"
        mysql guacamole < "$MYSQL_SCHEMA/001-create-schema.sql"
        mysql guacamole < "$MYSQL_SCHEMA/002-create-admin-user.sql"
        mkdir -p "$MYSQL_DATABASE/guacamole" && echo "1.6.0" > "$MYSQL_DATABASE/guacamole/version"
        mysqladmin shutdown
        wait $TEMP_PID
    else
        echo "[$(date)] ERROR: Database failed to start. Check /config/databases/mysql_safe.log"
        exit 1
    fi
fi

# 4. VÉGLEGES ÁTADÁS - Vissza a juice-nak (1000)
echo "[$(date)] Finalizing permissions for abc user..."
chown -R abc:users "$MYSQL_DATABASE" /var/run/mysqld /var/log/mysql
chmod -R 755 "$MYSQL_DATABASE" /var/run/mysqld
exec /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --user=abc
