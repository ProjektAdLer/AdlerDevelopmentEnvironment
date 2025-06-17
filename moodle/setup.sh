#!/bin/bash

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --dbhost HOST      Set database host (default: 127.0.0.1)"
    echo "  -p, --dbport PORT      Set database port (default: 3312 for Docker, 3306 for local)"
    echo "  -s, --skip-docker      Skip Docker setup and use another MariaDB server. Set credentials in .env file."
    echo "  -y, --yes              Auto-accept all system changes without prompting"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                     # Default setup with Docker MariaDB"
    echo "  $0 --skip-docker       # Do not start mariaDB in Docker"
    echo "  $0 -d 192.168.1.100 -s # Use existing MariaDB on 192.168.1.100 and skip Docker setup"
    echo "  $0 -y                  # Auto-accept all system modifications"
    exit 0
}

# Function to confirm system changes
confirm_system_change() {
    local message="$1"
    
    echo ""
    echo "⚠️  SYSTEM MODIFICATION REQUIRED"
    echo "   $message"
    echo ""
    
    if [ "$AUTO_ACCEPT" = true ]; then
        echo "Auto-accepting system change (--yes flag provided)"
        COMPLETED_MODIFICATIONS+=("$message")
        return 0
    fi
    
    read -p "Do you want to proceed with this system change? [y/N]: " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "System change declined. Exiting."
        show_system_modifications_summary
        exit 1
    fi
    
    COMPLETED_MODIFICATIONS+=("$message")
}

# Function to show summary of system modifications
show_system_modifications_summary() {
    echo ""
    if [ ${#COMPLETED_MODIFICATIONS[@]} -eq 0 ]; then
        echo "No system modifications were made."
    else
        echo "The following changes were made to the system:"
        for modification in "${COMPLETED_MODIFICATIONS[@]}"; do
            echo "- $modification"
        done
    fi
}


# configuration
MOODLE_PORT=5080  # this is the port the moodle is available at
PHP_VERSION=8.3
MOODLE_TAG=v5.0.0

# Default value for DB_HOST
DB_HOST="127.0.0.1"
# Default value for skipping Docker
SKIP_DOCKER=false
# Default value for auto-accepting system changes
AUTO_ACCEPT=false
# Set default DB port based on Docker usage (will be updated after parsing arguments)
DB_PORT=""

# Array to track completed system modifications
COMPLETED_MODIFICATIONS=()

WSL_USER=$(whoami)
MOODLE_PARENT_DIRECTORY=$(getent passwd $WSL_USER | cut -d: -f6)/moodle
HOST_IP=$(ip route | grep default | awk '{print $3}')

if [ "$WSL_USER" == "root" ]; then
    echo "Script cannot be run as root. Exiting."
    exit 1
fi

# Parse command line arguments for DB_HOST
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dbhost|-d) DB_HOST="$2"; shift ;;
        --dbport|-p) DB_PORT="$2"; shift ;;
        --skip-docker|-s) SKIP_DOCKER=true ;;
        --yes|-y) AUTO_ACCEPT=true ;;
        --help|-h) show_usage ;;
        *) ;;
    esac
    shift
done
echo "DB_HOST is set to $DB_HOST"
echo "SKIP_DOCKER is set to $SKIP_DOCKER"

# Set DB_PORT based on Docker usage
if [ "$SKIP_DOCKER" = true ]; then
    DB_PORT=${DB_PORT:-3306}  # Default MariaDB port for local installation
    echo "Using local MariaDB setup (Docker will be skipped)"
else
    DB_PORT=${DB_PORT:-3312}  # Docker compose port
    echo "Using Docker-based MariaDB setup"
fi
echo "DB_PORT is set to $DB_PORT"

cd "$(dirname "$0")"

# load additional environment variables from .env to be as close to non-moodle as possible
set -o allexport
source .env
set +o allexport

# check if moodle is already installed
if [ -f $MOODLE_PARENT_DIRECTORY/moodle/config.php ]
then
    echo "Moodle is already installed. You have to reset your environment first. See documentation. If you want to restore a previous moodle installation, do it after running this script."
    exit 1
fi

# check docker is available (skip if --skip-docker is used)
if [ "$SKIP_DOCKER" = false ]; then
    # grant docker access to the current user
    confirm_system_change "Adding user '$WSL_USER' to 'docker' group for Docker access"
    sudo usermod -aG docker $WSL_USER

    if ! docker &> /dev/null
    then
        echo "Docker is not working as expected."
        docker
        exit 1
    fi
    
fi

# update package list and upgrade packages
confirm_system_change "Installing/updating system packages (PHP $PHP_VERSION, MariaDB client, Composer, etc.)"
sudo apt update
sudo apt dist-upgrade -y

# install dependencies
sudo apt install -y acl php$PHP_VERSION php$PHP_VERSION-curl php$PHP_VERSION-zip composer php$PHP_VERSION-gd php$PHP_VERSION-dom php$PHP_VERSION-xml php$PHP_VERSION-mysqli php$PHP_VERSION-soap php$PHP_VERSION-xmlrpc php$PHP_VERSION-intl php$PHP_VERSION-xdebug php$PHP_VERSION-pgsql php$PHP_VERSION-tidy mariadb-client default-jre zstd

# install locales
confirm_system_change "Configuring system locales (de_DE.UTF-8, en_AU.UTF-8)"
sudo sed -i 's/^# de_DE.UTF-8 UTF-8$/de_DE.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i 's/^# en_AU.UTF-8 UTF-8$/en_AU.UTF-8 UTF-8/' /etc/locale.gen   # hardcoded for some testing stuff in moodle
sudo locale-gen


# create moodle parent directory and subdirectories
mkdir -p $MOODLE_PARENT_DIRECTORY
mkdir $MOODLE_PARENT_DIRECTORY/moodledata $MOODLE_PARENT_DIRECTORY/moodledata_phpu $MOODLE_PARENT_DIRECTORY/moodledata_bht
# download moodle to $MOODLE_PARENT_DIRECTORY/moodle
git clone --depth 1 --branch $MOODLE_TAG https://github.com/moodle/moodle.git  $MOODLE_PARENT_DIRECTORY/moodle

# setup database
if [ "$SKIP_DOCKER" = false ]; then
    docker compose up -d --wait
else
    echo "Skipping Docker database setup. Assuming local MariaDB is already running."
fi

# configure php
confirm_system_change "Creating PHP configuration files for Moodle and XDebug in /etc/php/$PHP_VERSION/"
## Create moodle.ini with all PHP settings
cat << EOF | sudo tee /etc/php/$PHP_VERSION/cli/conf.d/moodle.ini
; Moodle-specific PHP configuration
max_input_vars = 5000
upload_max_filesize = 2048M
post_max_size = 2048M
memory_limit = 256M
EOF


echo "[XDebug]
# https://xdebug.org/docs/all_settings
zend_extension = xdebug

xdebug.mode=debug
;xdebug.mode=develop
xdebug.client_port=9000

; host ip address of wsl network adapter
xdebug.client_host=$HOST_IP

; idekey value is specific to PhpStorm
xdebug.idekey=phpstorm

// always enabling debugging slows down the web interface significantly.
// Instead prefer to enable debugging only when needed. See README.md for more information.
;xdebug.start_with_request=true
" | sudo tee /etc/php/$PHP_VERSION/cli/conf.d/20-xdebug.ini

# install moodle
php $MOODLE_PARENT_DIRECTORY/moodle/admin/cli/install.php --lang=DE --wwwroot=http://localhost:$MOODLE_PORT --dataroot=$MOODLE_PARENT_DIRECTORY/moodledata --dbtype=mariadb --dbhost=$DB_HOST --dbport=$DB_PORT --dbuser=${_DB_MOODLE_USER} --dbpass=${_DB_MOODLE_PW} --dbname=${_DB_MOODLE_NAME} --fullname=fullname --shortname=shortname --adminuser=${_MOODLE_USER} --adminpass=${_MOODLE_PW} --adminemail=admin@blub.blub --supportemail=admin@blub.blub --non-interactive --agree-license

# moodle config.php
# remove the require_once line as it has to be at the end of the file
sed -i "/require_once(__DIR__ . '\/lib\/setup.php');/d" $MOODLE_PARENT_DIRECTORY/moodle/config.php
# If changing anything on this template: absolutely pay attention to escape $ (if shouln't be evaluated) and "
echo "
//=========================================================================
// 7. SETTINGS FOR DEVELOPMENT SERVERS - not intended for production use!!!
//=========================================================================

// configure phpunit
\$CFG->phpunit_prefix = 'phpu_';
\$CFG->phpunit_dataroot = '$MOODLE_PARENT_DIRECTORY/moodledata_phpu';
// \$CFG->phpunit_profilingenabled = true; // optional to profile PHPUnit runs.

// Force a debugging mode regardless the settings in the site administration
@error_reporting(E_ALL | E_STRICT); // NOT FOR PRODUCTION SERVERS!
@ini_set('display_errors', '1');    // NOT FOR PRODUCTION SERVERS!
\$CFG->debug = (E_ALL | E_STRICT);   // === DEBUG_DEVELOPER - NOT FOR PRODUCTION SERVERS!
\$CFG->debugdisplay = 1;             // NOT FOR PRODUCTION SERVERS!

// Force result of checks used to determine whether a site is considered \"public\" or not (such as for site registration).
// \$CFG->site_is_public = false;

# disable some caching (recommended by moodle introduction course)
\$CFG->langstringcache = 0;
\$CFG->cachetemplates = 0;
\$CFG->cachejs = 0;

//=========================================================================
// 11. BEHAT SUPPORT
//=========================================================================
// Behat test site needs a unique www root, data directory and database prefix:
//
\$CFG->behat_wwwroot = 'http://127.0.0.1:$MOODLE_PORT';
\$CFG->behat_prefix = 'bht_';
\$CFG->behat_dataroot = '$MOODLE_PARENT_DIRECTORY/moodledata_bht';

require_once('$MOODLE_PARENT_DIRECTORY/moodle/moodle-browser-config/init.php');
require_once(__DIR__ . '/lib/setup.php'); // Do not edit
" >> $MOODLE_PARENT_DIRECTORY/moodle/config.php

cd $MOODLE_PARENT_DIRECTORY/moodle
# install composer dependencies
composer i

#clone behat test browser config repo
git clone https://github.com/andrewnicols/moodle-browser-config

# Create start script from template
cp ../start.sh.template start.sh
sed -i "s/REPLACE_PORT/$MOODLE_PORT/g" start.sh
chmod +x start.sh

# setup test environments
echo "Run the following commands to setup the test environments:"
echo php admin/tool/phpunit/cli/init.php
echo php admin/tool/behat/cli/init.php

echo moodle login data: username: ${_MOODLE_USER} password: ${_MOODLE_PW}
if [ "$SKIP_DOCKER" = false ]; then
    echo db root password: ${_DB_ROOT_PW}
else
    echo "Using local MariaDB database on $DB_HOST:$DB_PORT"
fi
echo "Host IP (for IDE config): $HOST_IP"
echo ""
echo "Setup complete! To start Moodle with PHP built-in server and cron jobs, run:"
echo "cd $MOODLE_PARENT_DIRECTORY/moodle && ./start.sh"
echo ""
echo "Or to start manually (without automatic cron jobs):"
echo "cd $MOODLE_PARENT_DIRECTORY/moodle && php -S localhost:$MOODLE_PORT"
echo ""
echo "Moodle will be available at http://localhost:$MOODLE_PORT"

# Show summary of system modifications
show_system_modifications_summary
