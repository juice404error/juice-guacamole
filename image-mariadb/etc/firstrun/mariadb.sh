#!/bin/bash

MYSQL_DATABASE="/config/databases"
MYSQL_SCHEMA="/config/mysql-schema"

mkdir -p /var/run/mysqld /var/log/mysql "$MYSQL_DATABASE"
chown -R abc:users /var/run/mysqld /var/log/mysql "$MYSQL_DATABASE"

if [ ! -d "$MYSQL_DATABASE/guacamole" ]; then
    echo "Initializing new MariaDB database..."
    mysql_install_db --user=abc --datadir="$MYSQL_DATABASE" --skip-test-db > /dev/null
    
    # Indítás speciális módban a root jelszó fixálásához
    /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" --skip-networking --skip-grant-tables &
    PID=$!
    until mysqladmin ping --silent; do sleep 2; done
    
    PW=$(grep -m 1 "mysql-password:" /config/guacamole/guacamole.properties | awk '{print $2}')
    
    mysql -e "CREATE DATABASE IF NOT EXISTS guacamole;"
    mysql -e "FLUSH PRIVILEGES;"
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '';"
    mysql -e "CREATE USER IF NOT EXISTS 'guacamole'@'localhost' IDENTIFIED BY '$PW';"
    mysql -e "GRANT ALL PRIVILEGES ON guacamole.* TO 'guacamole'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
    
    echo "Loading schemas from $MYSQL_SCHEMA..."
    mysql guacamole < "$MYSQL_SCHEMA/001-create-schema.sql"
    mysql guacamole < "$MYSQL_SCHEMA/002-create-admin-user.sql"
    
    mkdir -p "$MYSQL_DATABASE/guacamole"
    echo "1.6.0" > "$MYSQL_DATABASE/guacamole/version"
    
    kill $PID
    sleep 5
fi
