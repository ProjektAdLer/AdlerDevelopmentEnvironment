#!/bin/bash
WSL_USER=$(whoami)
MOODLE_PARENT_DIRECTORY=$(getent passwd $WSL_USER | cut -d: -f6)/moodle

# Default values
DB_HOST="127.0.0.1"
SKIP_DOCKER=false
DB_PORT=""

if [ "$WSL_USER" == "root" ]; then
    echo "Script cannot be run as root. Exiting."
    exit 1
fi

# Parse command line arguments for DB_HOST and backup file path
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dbhost|-d) DB_HOST="$2"; shift 2 ;;
        --dbport|-p) DB_PORT="$2"; shift 2 ;;
        --skip-docker|-s) SKIP_DOCKER=true; shift ;;
        *) backup_archive="$1"; shift ;;
    esac
done

# Set DB_PORT based on Docker usage
if [ "$SKIP_DOCKER" = true ]; then
    DB_PORT=${DB_PORT:-3306}  # Default MariaDB port for local installation
else
    DB_PORT=${DB_PORT:-3312}  # Docker compose port
fi

cd "$(dirname "$0")"

# echo settings
echo "DB_HOST is set to $DB_HOST"
echo "DB_PORT is set to $DB_PORT"
echo "SKIP_DOCKER is set to $SKIP_DOCKER"
echo "Backup archive is set to $backup_archive"

# Load environment variables
set -o allexport
source .env
set +o allexport

# check if backup archive exists
if [ ! -f "$backup_archive" ]; then
  echo "Backup archive not found."
  exit 1
fi

echo "First, backup everything."
# Execute the backup_data.sh script with the same parameters
if [ "$SKIP_DOCKER" = true ]; then
    ./backup_data.sh --dbhost $DB_HOST --dbport $DB_PORT --skip-docker
else
    ./backup_data.sh --dbhost $DB_HOST --dbport $DB_PORT
fi

# Decide which decompression command to use based on the file extension
if [[ $backup_archive == *.tar.zst ]]; then
  decompression_command="zstd -d --memory=2048MB --stdout"
elif [[ $backup_archive == *.tar.gz ]]; then
  decompression_command="gzip -d -c"
else
  echo "Unsupported archive format. Please use .tar.zst or .tar.gz"
  exit 1
fi

# Empty the existing Moodle database
echo "Emptying existing Moodle database..."
tables_to_drop=$(mysql -h $DB_HOST -P $DB_PORT -u root -p"$_DB_ROOT_PW" $_DB_MOODLE_NAME -sN -e 'SHOW TABLES')
if [ -z "$tables_to_drop" ]; then
  echo "No tables found in database. Skipping the drop tables step."
else
  tables_to_drop=\`$(echo $tables_to_drop | sed 's/ /`,`/g')\`
  sql_statement="SET FOREIGN_KEY_CHECKS = 0; DROP TABLE IF EXISTS $tables_to_drop; SET FOREIGN_KEY_CHECKS = 1;"
#  echo "$sql_statement"

  mysql -h $DB_HOST -P $DB_PORT -u root -p"$_DB_ROOT_PW" $_DB_MOODLE_NAME -e "$sql_statement"
  if [ $? -ne 0 ]; then
    echo "Failed to empty the existing Moodle database. Exiting."
    exit 1
  fi
fi


# Temporary directory for restoration
restore_dir="/tmp/moodle_restore_$(date +'%Y-%m-%d_%H-%M-%S')"

# Create temporary directory
mkdir -p "$restore_dir"

# Decompress and extract archive
tar --use-compress-program="$decompression_command" -xf "$backup_archive" -C "$restore_dir"

# Extract the folder name that contains the backup
backup_folder_name=$(ls "$restore_dir")

# Full path to the backup data
full_restore_path="$restore_dir/$backup_folder_name"

# clear moodledata and moodledata_phpu
sudo rm -rf $MOODLE_PARENT_DIRECTORY/moodledata/*

# Restore files and database
cp -r "$full_restore_path/moodledata" $MOODLE_PARENT_DIRECTORY/
cp "$full_restore_path/config.php" $MOODLE_PARENT_DIRECTORY/moodle/config.php
mysql -h $DB_HOST -P $DB_PORT -u root -p"$_DB_ROOT_PW" $_DB_MOODLE_NAME < "$full_restore_path/moodle_database.sql"

# Restore ACLs if backup exists
if [ -f "$full_restore_path/moodledata.acl" ]; then
    echo "Restoring ACLs..."
    sudo setfacl --restore="$full_restore_path/moodledata.acl"
else
    echo "No ACL backup found (likely an older backup). Not setting ACLs."
fi

# Clean up
rm -rf "$restore_dir"


# Print success message
echo "----------------------------------"
echo "Data restored from $backup_archive"

# Print info about test environments
echo "There is no point in backing up and restoring phpu and bht. Use moodle commands to initialize them. For bht you have to empty the data directory first (if it exists): 'rm -r <path to mooodledata_bht>/*'."
echo "php admin/tool/phpunit/cli/init.php"
echo "php admin/tool/behat/cli/init.php"
