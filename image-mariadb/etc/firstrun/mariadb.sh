#!/bin/bash
MYSQL_DATABASE="/config/databases"
MYSQL_SCHEMA="/config/mysql-schema"
MYSQL_CONFIG="/etc/my.cnf.d/mariadb-server.cnf"

echo "[$(date)] Starting MariaDB initialization..."

# 1. Konfiguráció fixálása
if ! grep -q "skip-log-bin" "$MYSQL_CONFIG"; then
    sed -i "/\[mysqld\]/a skip-log-bin" "$MYSQL_CONFIG"
    sed -i "s/bind-address.*/bind-address = 0.0.0.0/" "$MYSQL_CONFIG" || echo "bind-address = 0.0.0.0" >> "$MYSQL_CONFIG"
fi

# 2. Inicializálás, ha szükséges
if [ ! -d "$MYSQL_DATABASE/mysql" ]; then
    echo "[$(date)] Fresh install, initializing MariaDB structure..."
    mkdir -p "$MYSQL_DATABASE" /var/log/mysql
    chown -R abc:abc "$MYSQL_DATABASE" /var/log/mysql
    
    # mysql_install_db -> mariadb-install-db
    mariadb-install-db --user=abc --datadir="$MYSQL_DATABASE" --skip-test-db > /dev/null 2>&1
    
    # mysqld -> mariadbd
    /usr/bin/mariadbd --datadir="$MYSQL_DATABASE" --user=abc --skip-log-bin --skip-networking &
    TEMP_PID=$!
    
    echo "[$(date)] Waiting for database..."
    COUNT=0
    # mysqladmin -> mariadb-admin
    until mariadb-admin -u root status > /dev/null 2>&1 || [ $COUNT -eq 30 ]; do sleep 1; COUNT=$((COUNT+1)); done

    if mariadb-admin -u root status > /dev/null 2>&1; then
        PW=$(grep -m 1 "mysql-password:" /config/guacamole/guacamole.properties | awk '{print $2}')
        
        # mysql -> mariadb
        mariadb -e "ALTER USER 'root'@'localhost' IDENTIFIED BY ''; CREATE DATABASE IF NOT EXISTS guacamole; CREATE USER IF NOT EXISTS 'guacamole'@'%' IDENTIFIED BY '$PW'; GRANT ALL PRIVILEGES ON guacamole.* TO 'guacamole'@'%'; FLUSH PRIVILEGES;"
        mariadb guacamole < "$MYSQL_SCHEMA/001-create-schema.sql"
        mariadb guacamole < "$MYSQL_SCHEMA/002-create-admin-user.sql"
        
        mkdir -p "$MYSQL_DATABASE/guacamole"
        echo "1.6.0" > "$MYSQL_DATABASE/guacamole/version"
        
        # mysqladmin -> mariadb-admin
        mariadb-admin shutdown
        wait $TEMP_PID
    fi
fi

# 3. VÉGLEGES INDÍTÁS
echo "[$(date)] Starting MariaDB bin directly as abc..."
# mysqld -> mariadbd
exec /usr/bin/mariadbd --basedir=/usr --datadir="$MYSQL_DATABASE" --plugin-dir=/usr/lib/mysql/plugin --skip-log-error --log-error=/config/log/mysql.log --pid-file=/var/run/mysqld/mysqld.pid --socket=/var/run/mysqld/mysqld.sock --user=abc --skip-log-bin --bind-address=0.0.0.0 --port=3306
