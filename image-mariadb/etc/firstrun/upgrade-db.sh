#!/bin/bash
# Guacamole MySQL/MariaDB Schema Upgrade Script

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

# Beállítjuk a jelszót a MySQL kliens számára
export MYSQL_PWD=$DB_PASS

if [ -z "$MYSQL_PWD" ]; then
    echo "ERROR: Could not find mysql-password in $PROPS_FILE!"
    exit 1
fi

echo "Connecting to $DB_USER @ $DB_HOST (Port: ${DB_PORT:-3306})..."

SCHEMA_DIR="/config/mysql-schema/upgrade"
if [ ! -d "$SCHEMA_DIR" ]; then
    echo "No upgrade directory found at $SCHEMA_DIR."
    exit 0
fi

echo "Found upgrade scripts. Starting update process..."

# Sorban lefuttatjuk az SQL fájlokat
for sql_file in $(ls $SCHEMA_DIR/*.sql | sort -V); do
    echo "Applying update: $(basename $sql_file)..."
    
    # Futtatás. A -h és -P paramétereket is használjuk a biztonság kedvéért.
    mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" "$DB_NAME" < "$sql_file"
    
    if [ $? -eq 0 ]; then
        echo "Successfully applied $(basename $sql_file)"
    else
        echo "Note: Could not apply $(basename $sql_file) (it might have been applied already)."
    fi
done

unset MYSQL_PWD
echo "--- Database upgrade process finished ---"
