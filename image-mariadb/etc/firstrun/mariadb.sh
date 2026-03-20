#!/bin/bash
MYSQL_DATABASE="/config/databases"
MYSQL_SCHEMA="/config/mysql-schema"
SOCKET="/var/run/mysqld/mysqld.sock"
PID_FILE="/var/run/mysqld/mysqld.pid"

# 1. Alapvető tisztítás és mappa ellenőrzés
echo "[$(date)] Starting MariaDB wrapper script..."
rm -f "$SOCKET" "$PID_FILE"
mkdir -p /var/run/mysqld
chown -R abc:users /var/run/mysqld "$MYSQL_DATABASE"

# 2. Inicializálás, ha még nem létezik az adatbázis
if [ ! -d "$MYSQL_DATABASE/guacamole" ]; then
    echo "[$(date)] Initializing new MariaDB database structure..."
    mysql_install_db --user=abc --datadir="$MYSQL_DATABASE" --skip-test-db --auth-root-authentication-method=normal
    
    echo "[$(date)] Starting MariaDB in maintenance mode..."
    /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --socket="$SOCKET" --skip-networking --skip-grant-tables --user=abc &
    TEMP_PID=$!
    
    # Várakozás a socket fájlra (max 30 mp)
    echo "[$(date)] Waiting for socket: $SOCKET"
    NEXT_WAIT=0
    until [ -S "$SOCKET" ] || [ $NEXT_WAIT -eq 30 ]; do
        sleep 1
        NEXT_WAIT=$((NEXT_WAIT+1))
    done

    if [ -S "$SOCKET" ]; then
        echo "[$(date)] Socket found, configuring database..."
        PW=$(grep -m 1 "mysql-password:" /config/guacamole/guacamole.properties | awk '{print $2}')
        
        # SQL parancsok - kényszerített sockettel
        mysql -S "$SOCKET" -e "FLUSH PRIVILEGES;"
        mysql -S "$SOCKET" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '';"
        mysql -S "$SOCKET" -e "CREATE DATABASE IF NOT EXISTS guacamole;"
        mysql -S "$SOCKET" -e "CREATE USER IF NOT EXISTS 'guacamole'@'localhost' IDENTIFIED BY '$PW';"
        mysql -S "$SOCKET" -e "GRANT ALL PRIVILEGES ON guacamole.* TO 'guacamole'@'localhost';"
        mysql -S "$SOCKET" -e "FLUSH PRIVILEGES;"
        
        echo "[$(date)] Loading Guacamole schemas..."
        mysql -S "$SOCKET" guacamole < "$MYSQL_SCHEMA/001-create-schema.sql"
        mysql -S "$SOCKET" guacamole < "$MYSQL_SCHEMA/002-create-admin-user.sql"
        
        mkdir -p "$MYSQL_DATABASE/guacamole"
        echo "1.6.0" > "$MYSQL_DATABASE/guacamole/version"
        
        echo "[$(date)] Maintenance mode finished, stopping temporary process..."
        mysqladmin -S "$SOCKET" shutdown
        wait $TEMP_PID
    else
        echo "[$(date)] ERROR: MariaDB socket never appeared. Check /config/databases/mysql_safe.log"
        kill $TEMP_PID
        exit 1
    fi
fi

# 3. Végleges indítás
echo "[$(date)] Starting MariaDB normally..."
exec /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --socket="$SOCKET" --user=abc
