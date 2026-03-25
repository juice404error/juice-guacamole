#!/bin/bash
# Guacamole MySQL/MariaDB Schema Upgrade Script

echo "--- Checking for database schema updates ---"

# Adatbázis adatok kinyerése a környezeti változókból
DB_HOST=${MYSQL_HOSTNAME:-"localhost"}
DB_NAME=${MYSQL_DATABASE:-"guacamole_db"}
DB_USER=${MYSQL_USER:-"guacamole_user"}

# FONTOS: A MySQL kliens ezt a változót automatikusan figyeli a jelszóhoz
export MYSQL_PWD=${MYSQL_PASSWORD}

# Ellenőrizzük, hogy van-e jelszó
if [ -z "$MYSQL_PWD" ]; then
    echo "ERROR: MYSQL_PASSWORD environment variable is not set!"
    exit 1
fi

# Keressük meg az összes sémát a frissítés mappában
SCHEMA_DIR="/config/mysql-schema/upgrade"

if [ ! -d "$SCHEMA_DIR" ]; then
    echo "No upgrade directory found at $SCHEMA_DIR."
    exit 0
fi

echo "Found upgrade scripts. Starting update process..."

# Sorba rendezve végigmegyünk az SQL fájlokon
for sql_file in $(ls $SCHEMA_DIR/*.sql | sort -V); do
    echo "Applying update: $(basename $sql_file)..."
    
    # Itt már nem kell a -p kapcsoló, mert a MYSQL_PWD környezeti változót használja
    mysql -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" < "$sql_file"
    
    if [ $? -eq 0 ]; then
        echo "Successfully applied $(basename $sql_file)"
    else
        echo "ERROR: Failed to apply $(basename $sql_file). Check if it was already applied."
    fi
done

# Töröljük a jelszót a környezetből a script végén biztonsági okokból
unset MYSQL_PWD

echo "--- Database upgrade process finished ---"
