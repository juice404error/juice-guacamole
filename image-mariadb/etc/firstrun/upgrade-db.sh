#!/bin/bash
# Guacamole MySQL/MariaDB Schema Upgrade Script

echo "--- Checking for database schema updates ---"

# Adatbázis adatok kinyerése a környezeti változókból vagy a configból
# Feltételezzük, hogy a környezeti változók (MYSQL_DATABASE, MYSQL_USER, stb.) elérhetőek
DB_HOST=${MYSQL_HOSTNAME:-"localhost"}
DB_NAME=${MYSQL_DATABASE:-"guacamole_db"}
DB_USER=${MYSQL_USER:-"guacamole_user"}
DB_PASS=${MYSQL_PASSWORD}

# Keressük meg az összes sémát a frissítés mappában
SCHEMA_DIR="/config/mysql-schema/upgrade"

if [ ! -d "$SCHEMA_DIR" ]; then
    echo "No upgrade directory found at $SCHEMA_DIR. Maybe no upgrade is needed for this version."
    exit 0
fi

echo "Found upgrade scripts. Starting update process..."

# Sorba rendezve végigmegyünk az SQL fájlokon
for sql_file in $(ls $SCHEMA_DIR/*.sql | sort -V); do
    echo "Applying update: $(basename $sql_file)..."
    
    # Lefuttatjuk az SQL-t. A -f (force) segít, ha egy tábla már létezne.
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$sql_file"
    
    if [ $? -eq 0 ]; then
        echo "Successfully applied $(basename $sql_file)"
    else
        echo "ERROR: Failed to apply $(basename $sql_file)"
    fi
done

echo "--- Database upgrade process finished ---"
