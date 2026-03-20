#!/bin/bash

MYSQL_DATABASE="/config/databases"
MYSQL_SCHEMA="/opt/guacamole/mysql/schema"

mkdir -p /var/run/mysqld /var/log/mysql "$MYSQL_DATABASE"
chown -R abc:abc /var/run/mysqld /var/log/mysql "$MYSQL_DATABASE"

start_mysql() {
    /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" > /dev/null 2>&1 &
    while ! mysqladmin ping --silent; do sleep 1; done
}

stop_mysql() {
    mysqladmin -u root shutdown
    sleep 2
}

# Új adatbázis létrehozása
if [ ! -d "$MYSQL_DATABASE/guacamole" ]; then
    if [ -f /config/guacamole/guacamole.properties ]; then
        echo "Initializing new MariaDB database..."
        mysql_install_db --user=abc --datadir="$MYSQL_DATABASE" > /dev/null
        
        start_mysql
        
        # Jelszó kinyerése (a te grep parancsoddal)
        PW=$(grep -m 1 "mysql-password:" /config/guacamole/guacamole.properties | awk '{print $2}')
        
        mysql -uroot -e "CREATE DATABASE guacamole;"
        mysql -uroot -e "CREATE USER 'guacamole'@'localhost' IDENTIFIED BY '$PW';"
        mysql -uroot -e "GRANT ALL PRIVILEGES ON guacamole.* TO 'guacamole'@'localhost';"
        mysql -uroot -e "FLUSH PRIVILEGES;"
        
        echo "Loading schemas..."
        mysql -uroot guacamole < "$MYSQL_SCHEMA/001-create-schema.sql"
        mysql -uroot guacamole < "$MYSQL_SCHEMA/002-create-admin-user.sql"
        
        echo "$GUAC_VER" > "$MYSQL_DATABASE/guacamole/version"
        stop_mysql
        echo "Database initialization complete."
    else
        echo "CRITICAL: guacamole.properties not found, cannot init database!"
    fi
fi

# Indítás az előtérben a Supervisord számára
echo "Starting MariaDB..."
exec /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE"
