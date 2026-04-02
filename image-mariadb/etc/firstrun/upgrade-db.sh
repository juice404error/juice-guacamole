#!/bin/bash
# Guacamole MariaDB Schema Upgrade Script

echo "--- Checking for database schema updates ---"

PROPS_FILE="/config/guacamole/guacamole.properties"

if [ ! -f "$PROPS_FILE" ]; then
    echo "ERROR: Config file $PROPS_FILE not found!"
    exit 1
fi

echo "Reading database config from $PROPS_FILE..."

# Kinyerjük az adatokat (figyelve a kettőspont utáni szóközökre)
DB_HOST=$(grep "mysql-hostname:" "$PROPS_FILE" | awk '{print $2}')
DB_PORT=$(grep "mysql-port:" "$PROPS_FILE" | awk '{print $2}')
DB_NAME=$(grep "mysql-database:" "$PROPS_FILE" | awk '{print $2}')
DB_USER=$(grep "mysql-username:" "$PROPS_FILE" | awk '{print $2}')
DB_PASS=$(grep "mysql-password:" "$PROPS_FILE" | awk '{print $2}')

# A MariaDB kliens is elfogadja a MYSQL_PWD változót, de a MARIADB_PWD a natív
export MARIADB_PWD=$DB_PASS
export MYSQL_PWD=$DB_PASS

if [ -z "$DB_PASS" ]; then
    echo "ERROR: Could not find mysql-password in $PROPS_FILE!"
    exit 1
fi

echo "Connecting to $DB_USER @ $DB_HOST (Port: ${DB_PORT:-3306})..."

SCHEMA_DIR="/config/mysql-schema/upgrade"
if [ ! -d "$SCHEMA_DIR" ] || [ -z "$(ls -A "$SCHEMA_DIR"/*.sql 2>/dev/null)" ]; then
    echo "No upgrade scripts found at $SCHEMA_DIR."
    exit 0
fi

echo "Found upgrade scripts. Starting update process..."

# Sorban lefuttatjuk az SQL fájlokat
for sql_file in $(ls "$SCHEMA_DIR"/*.sql | sort -V); do
    echo "Applying update: $(basename "$sql_file")..."
    
    # mysql -> mariadb csere
    mariadb -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" "$DB_NAME" < "$sql_file"
    
    if [ $? -eq 0 ]; then
        echo "Successfully applied $(basename "$sql_file")"
    else
        echo "Note: Could not apply $(basename "$sql_file") (it might have been applied already)."
    fi
done

unset MARIADB_PWD
unset MYSQL_PWD
echo "--- Database upgrade process finished ---"
