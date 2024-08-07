#!/bin/bash
MOODLE_PARENT_DIRECTORY=$(getent passwd 1000 | cut -d: -f6)

# Default value for DB_HOST
DB_HOST="127.0.0.1"

# Parse command line arguments for DB_HOST
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dbhost|-d) DB_HOST="$2"; shift ;;
        *) ;;
    esac
    shift
done

cd "$(dirname "$0")"

echo "-----------------------------------------"
echo "!!!This script is not properly tested.!!!"
echo "!!!Use at your own risk.!!!"
echo "-----------------------------------------"

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <path_to_backup_archive>"
  exit 1
fi

# Load environment variables
set -o allexport
source .env
set +o allexport

# check if backup archive exists
if [ ! -f "$1" ]; then
  echo "Backup archive not found."
  exit 1
fi

echo "First, backup everything."
# Execute the backup_data.sh script
./backup_data.sh --dbhost $DB_HOST

# Set variables
backup_archive="$1"

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
tables_to_drop=$(mysql -h $DB_HOST -P 3312 -u root -p"$_DB_ROOT_PW" $_DB_MOODLE_NAME -sN -e 'SHOW TABLES')
if [ -z "$tables_to_drop" ]; then
  echo "No tables found in database. Skipping the drop tables step."
else
  tables_to_drop=\`$(echo $tables_to_drop | sed 's/ /`,`/g')\`
  sql_statement="SET FOREIGN_KEY_CHECKS = 0; DROP TABLE IF EXISTS $tables_to_drop; SET FOREIGN_KEY_CHECKS = 1;"
#  echo "$sql_statement"

  mysql -h $DB_HOST -P 3312 -u root -p"$_DB_ROOT_PW" $_DB_MOODLE_NAME -e "$sql_statement"
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
rm -rf $MOODLE_PARENT_DIRECTORY/moodledata/*

# Restore files and database
cp -r "$full_restore_path/moodledata" $MOODLE_PARENT_DIRECTORY/
cp "$full_restore_path/config.php" $MOODLE_PARENT_DIRECTORY/moodle/config.php
mysql -h $DB_HOST -P 3312 -u root -p"$_DB_ROOT_PW" $_DB_MOODLE_NAME < "$full_restore_path/moodle_database.sql"

# Clean up
rm -rf "$restore_dir"


# Print success message
echo "----------------------------------"
echo "Data restored from $backup_archive"

# Print info about test environments
echo "There is no point in backing up and restoring phpu and bht. Use moodle commands to initialize them. For bht you have to empty the data directory first (if it exists): 'rm -r <path to mooodledata_bht>/*'."
echo "php admin/tool/phpunit/cli/init.php"
echo "php admin/tool/behat/cli/init.php"
