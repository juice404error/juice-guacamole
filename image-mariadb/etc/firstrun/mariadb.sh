#!/bin/bash
MYSQL_DATABASE="/config/databases"
MYSQL_SCHEMA="/config/mysql-schema"
MYSQL_CONFIG="/etc/my.cnf.d/mariadb-server.cnf"

echo "[$(date)] Starting MariaDB wrapper (User: abc)..."

# 1. Konfig injektálás (Jason-féle szóköz)
if ! grep -q "user=" "$MYSQL_CONFIG"; then
    sed -i "/\[mysqld\]/a user= abc" "$MYSQL_CONFIG"
fi

# 2. Inicializálás, ha az adatbázis még nem létezik
if [ ! -d "$MYSQL_DATABASE/mysql" ]; then
    echo "[$(date)] Fresh install, initializing MariaDB structure..."
    mkdir -p "$MYSQL_DATABASE"
    chown -R abc:users "$MYSQL_DATABASE"
    
    # Inicializálás abc-ként
    mysql_install_db --user=abc --datadir="$MYSQL_DATABASE" --skip-test-db > /dev/null 2>&1
    
    # Átmeneti indítás a sémák betöltéséhez
    /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --user=abc &
    TEMP_PID=$!
    
    echo "[$(date)] Waiting for database..."
    COUNT=0
    until mysqladmin -u root status > /dev/null 2>&1 || [ $COUNT -eq 30 ]; do sleep 1; COUNT=$((COUNT+1)); done

    if mysqladmin -u root status > /dev/null 2>&1; then
        PW=$(grep -m 1 "mysql-password:" /config/guacamole/guacamole.properties | awk '{print $2}')
        
        mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY ''; CREATE DATABASE IF NOT EXISTS guacamole; CREATE USER IF NOT EXISTS 'guacamole'@'localhost' IDENTIFIED BY '$PW'; GRANT ALL PRIVILEGES ON guacamole.* TO 'guacamole'@'localhost'; FLUSH PRIVILEGES;"
        
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

# 3. Végleges indítás abc-ként
echo "[$(date)] Starting MariaDB normally as abc..."
exec /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --user=abc
