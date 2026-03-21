#!/bin/bash
MYSQL_DATABASE="/config/databases"
MYSQL_SCHEMA="/config/mysql-schema"
SOCKET="/var/run/mysqld/mysqld.sock"
PID_FILE="/var/run/mysqld/mysqld.pid"

echo "[$(date)] Starting MariaDB wrapper as root..."

# 1. Kényszerített tisztítás (ha a recreate nem lett volna elég alapos)
if [ ! -f "$MYSQL_DATABASE/guacamole/version" ]; then
    echo "[$(date)] Fresh install or version mismatch detected, cleaning database directory..."
    rm -rf "${MYSQL_DATABASE:?}"/*
fi

# 2. Mappák és socket helyének előkészítése
rm -f "$SOCKET" "$PID_FILE"
mkdir -p /var/run/mysqld
chown -R abc:users /var/run/mysqld "$MYSQL_DATABASE"

# 3. Inicializálás (mivel root-ként fut a script, a chown hibák eltűnnek)
if [ ! -d "$MYSQL_DATABASE/mysql" ]; then
    echo "[$(date)] Initializing MariaDB structure..."
    mysql_install_db --user=abc --datadir="$MYSQL_DATABASE" --skip-test-db --auth-root-authentication-method=normal > /dev/null 2>&1
    
    echo "[$(date)] Starting maintenance mode..."
    /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --socket="$SOCKET" --skip-networking --skip-grant-tables --user=abc &
    TEMP_PID=$!
    
    # Várakozás a socketre
    echo "[$(date)] Waiting for socket: $SOCKET"
    COUNT=0
    until [ -S "$SOCKET" ] || [ $COUNT -eq 30 ]; do
        sleep 1
        COUNT=$((COUNT+1))
    done

    if [ -S "$SOCKET" ]; then
        echo "[$(date)] Loading schemas..."
        PW=$(grep -m 1 "mysql-password:" /config/guacamole/guacamole.properties | awk '{print $2}')
        
        # Alapbeállítások
        mysql -S "$SOCKET" -e "FLUSH PRIVILEGES; ALTER USER 'root'@'localhost' IDENTIFIED BY ''; CREATE DATABASE IF NOT EXISTS guacamole; CREATE USER IF NOT EXISTS 'guacamole'@'localhost' IDENTIFIED BY '$PW'; GRANT ALL PRIVILEGES ON guacamole.* TO 'guacamole'@'localhost'; FLUSH PRIVILEGES;"
        
        # Guacamole sémák
        mysql -S "$SOCKET" guacamole < "$MYSQL_SCHEMA/001-create-schema.sql"
        mysql -S "$SOCKET" guacamole < "$MYSQL_SCHEMA/002-create-admin-user.sql"
        
        mkdir -p "$MYSQL_DATABASE/guacamole"
        echo "1.6.0" > "$MYSQL_DATABASE/guacamole/version"
        
        echo "[$(date)] Maintenance mode finished, shutting down temporary process..."
        mysqladmin -S "$SOCKET" shutdown
        wait $TEMP_PID
    else
        echo "[$(date)] ERROR: Socket never appeared. Check /config/databases/mysql_safe.log"
        kill $TEMP_PID 2>/dev/null
        exit 1
    fi
fi

# 4. Végleges indítás: Átadjuk a vezérlést az abc usernek (1000-es juice)
echo "[$(date)] Starting MariaDB normally as abc user..."
chown -R abc:users "$MYSQL_DATABASE" /var/run/mysqld
exec /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --socket="$SOCKET" --user=abc
