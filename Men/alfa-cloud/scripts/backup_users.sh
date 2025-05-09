#!/bin/bash

BACKUP_DIR=backup
TIMESTAMP=$(date +%Y%m%d%H%M%S)
FILENAME=${BACKUP_DIR}/users_backup_${TIMESTAMP}.sql

mkdir -p $BACKUP_DIR

sqlite3 database/alfa-cloud.db ".dump users" > $FILENAME

if [ $? -eq 0 ]; then
  echo "Backup of users table created successfully at $FILENAME"
else
  echo "Backup failed!"
fi
