#!/bin/bash
MYSQL_DATABASE="/config/databases"
MYSQL_SCHEMA="/config/mysql-schema"
MYSQL_CONFIG="/etc/my.cnf.d/mariadb-server.cnf"

echo "[$(date)] Starting MariaDB wrapper..."

# 1. Konfiguráció fixálása (User, Bin-log skip és Network)
if ! grep -q "user=" "$MYSQL_CONFIG"; then
    sed -i "/\[mysqld\]/a user= abc" "$MYSQL_CONFIG"
    sed -i "/\[mysqld\]/a skip-log-bin" "$MYSQL_CONFIG"
    # Biztosítjuk, hogy ne csak localhoston, hanem a konténeren belül mindenhol elérhető legyen
    if grep -q "bind-address" "$MYSQL_CONFIG"; then
        sed -i "s/bind-address.*/bind-address = 0.0.0.0/" "$MYSQL_CONFIG"
    else
        echo "bind-address = 0.0.0.0" >> "$MYSQL_CONFIG"
    fi
fi

# 2. Inicializálás, ha szükséges
if [ ! -d "$MYSQL_DATABASE/mysql" ]; then
    echo "[$(date)] Fresh install, initializing MariaDB structure..."
    mkdir -p "$MYSQL_DATABASE" /var/log/mysql
    chown -R abc:users "$MYSQL_DATABASE" /var/log/mysql
    
    mysql_install_db --user=abc --datadir="$MYSQL_DATABASE" --skip-test-db > /dev/null 2>&1
    
    # Átmeneti indítás a sémákhoz
    /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --user=abc --skip-log-bin --skip-networking &
    TEMP_PID=$!
    
    echo "[$(date)] Waiting for database..."
    COUNT=0
    until mysqladmin -u root status > /dev/null 2>&1 || [ $COUNT -eq 30 ]; do sleep 1; COUNT=$((COUNT+1)); done

    if mysqladmin -u root status > /dev/null 2>&1; then
        PW=$(grep -m 1 "mysql-password:" /config/guacamole/guacamole.properties | awk '{print $2}')
        
        # Felhasználók létrehozása
        mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY ''; CREATE DATABASE IF NOT EXISTS guacamole; CREATE USER IF NOT EXISTS 'guacamole'@'%' IDENTIFIED BY '$PW'; GRANT ALL PRIVILEGES ON guacamole.* TO 'guacamole'@'%'; FLUSH PRIVILEGES;"
        
        # Sémák betöltése
        mysql guacamole < "$MYSQL_SCHEMA/001-create-schema.sql"
        mysql guacamole < "$MYSQL_SCHEMA/002-create-admin-user.sql"
        
        mkdir -p "$MYSQL_DATABASE/guacamole"
        echo "1.6.0" > "$MYSQL_DATABASE/guacamole/version"
        
        mysqladmin shutdown
        wait $TEMP_PID
    fi
fi

# 3. Végleges indítás
echo "[$(date)] Starting MariaDB normally as abc..."
exec /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --user=abc --skip-log-bin --bind-address=0.0.0.0
