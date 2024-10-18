#!/bin/bash

# Ruta al script de respaldo
BACKUP_SCRIPT="/home/webapp/backup.sh"

# Añadir el cron job para ejecutar el respaldo diariamente a las 2:00 AM
(crontab -l ; echo "0 2 * * * /bin/bash $BACKUP_SCRIPT >> /var/log/sftp-backup.log 2>&1") | crontab -

