#!/bin/bash

# Verzió lekérése a Dockerfile-ból (vagy környezeti változóból)
GUAC_VER=${GUAC_VER:-"1.5.5"}

MYSQL_CONFIG=/etc/my.cnf.d/mariadb-server.cnf
MYSQL_SCHEMA=/opt/guacamole/mysql/schema
MYSQL_DATABASE=/config/databases

# Könyvtárak előkészítése
mkdir -p /var/run/mysqld /var/log/mysql /config/databases
chown -R abc:abc /var/log/mysql /var/run/mysqld /config/databases
chmod -R 777 /var/run/mysqld

start_mysql() {
  echo "Starting MariaDB..."
  /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE" > /dev/null 2>&1 &
  RET=1
  while [[ RET -ne 0 ]]; do
      mysql -uroot -e "status" > /dev/null 2>&1
      RET=$?
      sleep 1
  done
}

stop_mysqld() {
  echo "Stopping MariaDB..."
  mysqladmin -u root shutdown
  sleep 3
}

# Adatbázis inicializálása, ha még nem létezik
if [ ! -d "$MYSQL_DATABASE"/guacamole ]; then
  if [ -f /config/guacamole/guacamole.properties ]; then
    echo "Initializing Guacamole database in $MYSQL_DATABASE"
    /usr/bin/mysql_install_db --user=abc --datadir="$MYSQL_DATABASE"
    
    start_mysql
    
    echo "Creating database and user..."
    mysql -uroot -e "CREATE DATABASE IF NOT EXISTS guacamole"
    
    # Jelszó kinyerése a properties fájlból
    PW=$(grep "mysql-password:" /config/guacamole/guacamole.properties | awk '{print $2}')
    
    mysql -uroot -e "CREATE USER IF NOT EXISTS 'guacamole'@'localhost' IDENTIFIED BY '$PW'"
    mysql -uroot -e "GRANT ALL PRIVILEGES ON guacamole.* TO 'guacamole'@'localhost'"
    mysql -uroot -e "FLUSH PRIVILEGES"
    
    echo "Loading schema..."
    mysql -uroot guacamole < ${MYSQL_SCHEMA}/001-create-schema.sql
    mysql -uroot guacamole < ${MYSQL_SCHEMA}/002-create-admin-user.sql
    
    echo "$GUAC_VER" > "$MYSQL_DATABASE"/guacamole/version
    stop_mysqld
    echo "Initialization complete."
  else
    echo "Error: guacamole.properties not found! Skipping DB init."
  fi
fi

# Indítás supervisord-on keresztül (előtérben tartva)
echo "Starting MariaDB in foreground..."
exec /usr/bin/mysqld_safe --datadir="$MYSQL_DATABASE"
