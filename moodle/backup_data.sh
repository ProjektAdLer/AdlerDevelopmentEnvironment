#!/bin/bash
WSL_USER=$(whoami)
MOODLE_PARENT_DIRECTORY=$(getent passwd $WSL_USER | cut -d: -f6)/moodle

if [ "$WSL_USER" == "root" ]; then
    echo "Script cannot be run as root. Exiting."
    exit 1
fi

# Default values
DB_HOST="127.0.0.1"
SKIP_DOCKER=false
DB_PORT=""

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dbhost|-d) DB_HOST="$2"; shift ;;
        --dbport|-p) DB_PORT="$2"; shift ;;
        --skip-docker|-s) SKIP_DOCKER=true ;;
        *) ;;
    esac
    shift
done

# Set DB_PORT based on Docker usage
if [ "$SKIP_DOCKER" = true ]; then
    DB_PORT=${DB_PORT:-3306}  # Default MariaDB port for local installation
else
    DB_PORT=${DB_PORT:-3312}  # Docker compose port
fi

echo "DB_HOST is set to $DB_HOST"
echo "DB_PORT is set to $DB_PORT"
echo "SKIP_DOCKER is set to $SKIP_DOCKER"

# Load additional environment variables from .env
set -o allexport
source "$(dirname "$0")/.env"
set +o allexport

echo "Starting backup..."

backup_datetime=$(date +'%Y-%m-%d_%H-%M-%S')
backup_dir="/tmp/${backup_datetime}_moodle_backup"

# Check which compression format to use
if command -v zstd &> /dev/null; then
  compression_format="zstd"
  compression_extension="tar.zst"
  compression_command="zstd --long=31 -6 --threads=0"
else
  compression_format="gzip"
  compression_extension="tar.gz"

  if command -v pigz &> /dev/null; then
    echo "zstd not found, but pigz found, using it for compression"
    echo "Install zstd for better/faster compression"
    compression_command="pigz -8"
  else
    echo "zstd and pigz not found, using gzip for compression"
    echo "Install zstd (or pigz) for better/faster compression"
    compression_command="gzip"
  fi
fi

# Create backup directory
mkdir -p $backup_dir

# fix acl (moodle sets acl mask to --- on some files)
for dir in moodledata; do
    sudo setfacl -R -m u:$WSL_USER:rwx,u:www-data:rwx,m::rwx "$MOODLE_PARENT_DIRECTORY/$dir"
    sudo setfacl -R -d -m u:$WSL_USER:rwx,u:www-data:rwx,m::rwx "$MOODLE_PARENT_DIRECTORY/$dir"
done

# Backup files
cp -r $MOODLE_PARENT_DIRECTORY/moodledata $backup_dir/
cp $MOODLE_PARENT_DIRECTORY/moodle/config.php $backup_dir/config.php

# Backup acl
getfacl -R $MOODLE_PARENT_DIRECTORY/moodledata > $backup_dir/moodledata.acl

# Backup database
mysqldump -h $DB_HOST -P $DB_PORT -u root -p"$_DB_ROOT_PW" $_DB_MOODLE_NAME > $backup_dir/moodle_database.sql

# Create compressed archive
start=$(date +%s%N)
tar -cf - -C /tmp ${backup_datetime}_moodle_backup | $compression_command > $MOODLE_PARENT_DIRECTORY/${backup_datetime}_moodle_backup.$compression_extension
echo "Archive duration: $(( ($(date +%s%N) - start) / 1000000 )) ms"

# Remove temporary backup folder
rm -rf $backup_dir

# Print success message
echo "Backup successfully created at $MOODLE_PARENT_DIRECTORY/${backup_datetime}_moodle_backup.$compression_extension"
