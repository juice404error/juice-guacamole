#!/bin/bash
MYSQL_DATABASE="/config/databases"
MYSQL_SCHEMA="/config/mysql-schema"

rm -f /var/run/mysqld/mysqld.sock /var/run/mysqld/mysqld.pid

if [ ! -d "$MYSQL_DATABASE/guacamole" ]; then
    echo "Initializing new MariaDB database..."
    # Hozzáadva: --auth-root-authentication-method=normal a hiba elkerülésére
    mysql_install_db --user=abc --datadir="$MYSQL_DATABASE" --skip-test-db --auth-root-authentication-method=normal > /dev/null 2>&1
    
    /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --skip-networking --skip-grant-tables --user=abc &
    PID=$!
    
    until mysqladmin ping --silent; do sleep 2; done
    
    PW=$(grep -m 1 "mysql-password:" /config/guacamole/guacamole.properties | awk '{print $2}')
    
    mysql -e "FLUSH PRIVILEGES;"
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '';"
    mysql -e "CREATE DATABASE IF NOT EXISTS guacamole;"
    mysql -e "CREATE USER IF NOT EXISTS 'guacamole'@'localhost' IDENTIFIED BY '$PW';"
    mysql -e "GRANT ALL PRIVILEGES ON guacamole.* TO 'guacamole'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
    
    echo "Loading schemas..."
    mysql guacamole < "$MYSQL_SCHEMA/001-create-schema.sql"
    mysql guacamole < "$MYSQL_SCHEMA/002-create-admin-user.sql"
    
    mkdir -p "$MYSQL_DATABASE/guacamole"
    echo "1.6.0" > "$MYSQL_DATABASE/guacamole/version"
    
    kill $PID
    wait $PID
    sleep 2
fi

echo "Starting MariaDB..."
exec /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE"
