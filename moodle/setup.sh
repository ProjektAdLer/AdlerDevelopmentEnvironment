#!/bin/bash
# TODO update/test with ubuntu 24.04
WSL_USER=$(whoami)
MOODLE_PARENT_DIRECTORY=$(getent passwd $WSL_USER | cut -d: -f6)
HOST_IP=$(ip route | grep default | awk '{print $3}')

if [ "$WSL_USER" == "root" ]; then
    echo "Script cannot be run as root. Exiting."
    exit 1
fi

# configuration
APACHE_VHOST_PORT=5080  # this is the port the moodle is available at
PHP_VERSION=8.3

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
echo "DB_HOST is set to $DB_HOST"

cd "$(dirname "$0")"

# load additional environment variables from .env to be as close to non-moodle as possible
set -o allexport
source .env
set +o allexport

# check if moodle is already installed
if [ -f $MOODLE_PARENT_DIRECTORY/moodle/config.php ]
then
    echo "Moodle is already installed. Please run reset_data.sh first."
    exit 1
fi

# check docker is available
if ! docker &> /dev/null
then
    echo "Docker is not working as expected."
    docker
    exit 1
fi

# update package list and upgrade packages
sudo apt update
sudo apt dist-upgrade -y

# install dependencies
sudo apt install -y apache2 php$PHP_VERSION php$PHP_VERSION-curl php$PHP_VERSION-zip composer php$PHP_VERSION-gd php$PHP_VERSION-dom php$PHP_VERSION-xml php$PHP_VERSION-mysqli php$PHP_VERSION-soap php$PHP_VERSION-xmlrpc php$PHP_VERSION-intl php$PHP_VERSION-xdebug php$PHP_VERSION-pgsql php$PHP_VERSION-tidy mariadb-client default-jre zstd

# install locales
sudo sed -i 's/^# de_DE.UTF-8 UTF-8$/de_DE.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i 's/^# en_AU.UTF-8 UTF-8$/en_AU.UTF-8 UTF-8/' /etc/locale.gen   # hardcoded for some testing stuff in moodle
sudo locale-gen


# create moodle folders
mkdir $MOODLE_PARENT_DIRECTORY/moodledata $MOODLE_PARENT_DIRECTORY/moodledata_phpu $MOODLE_PARENT_DIRECTORY/moodledata_bht
# download moodle to $MOODLE_PARENT_DIRECTORY/moodle

# setup database
# TODO: healthcheck for db and then --wait
sudo --preserve-env docker compose up -d
# Define a timeout of 20 seconds
TIMEOUT=15
# Check the database status every second
for ((i=0; i<TIMEOUT; i++)); do
    if mysqladmin ping -h $DB_HOST -P3312 --connect-timeout=5 --silent 2>/dev/null; then
        echo "db is up"
        break
    fi
    echo "db is starting"
    sleep 1
done
if [ $i -eq $TIMEOUT ]; then
    echo "Error: Database did not start within $TIMEOUT seconds."
    exit 1
fi

# configure apache
# Create a new virtual host configuration file
echo "<VirtualHost *:$APACHE_VHOST_PORT>
    DocumentRoot $MOODLE_PARENT_DIRECTORY/moodle
    <Directory $MOODLE_PARENT_DIRECTORY>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/moodle_error.log
    CustomLog \${APACHE_LOG_DIR}/moodle_access.log combined
</VirtualHost>" | sudo tee /etc/apache2/sites-available/moodle.conf
# Enable the new virtual host configuration
sudo a2ensite moodle.conf
# Add the custom port to ports.conf
echo "Listen $APACHE_VHOST_PORT" | sudo tee -a /etc/apache2/ports.conf
# Change user and group of apache to the user of the WSL
## Set ACLs to ensure both users have read, write, and execute permissions on the directory, its subdirectories, and existing files
#sudo setfacl -R -m u:$USER1:rwx,u:$USER2:rwx $TARGET_DIRECTORY
## Ensure default ACLs are set for new files and directories
#sudo setfacl -R -d -m u:$USER1:rwx,u:$USER2:rwx $TARGET_DIRECTORYsudo sed -i "s#export APACHE_RUN_USER=www-data#export APACHE_RUN_USER=$WSL_USER#g" /etc/apache2/envvars
sudo sed -i "s#export APACHE_RUN_GROUP=www-data#export APACHE_RUN_GROUP=$WSL_USER#g" /etc/apache2/envvars

# configure php
## conf.d/moodle.ini
echo "max_input_vars = 5000" | sudo tee /etc/php/$PHP_VERSION/cli/conf.d/moodle.ini
sudo ln -s  /etc/php/$PHP_VERSION/cli/conf.d/moodle.ini /etc/php/$PHP_VERSION/apache2/conf.d/moodle.ini
## apache/php.ini
sudo sed -i 's/^\(\s*;\?\s*\)upload_max_filesize\s*=\s*[0-9]*M/\upload_max_filesize = 2048M/' /etc/php/$PHP_VERSION/apache2/php.ini
sudo sed -i 's/^\(\s*;\?\s*\)post_max_size\s*=\s*[0-9]*M/\post_max_size = 2048M/' /etc/php/$PHP_VERSION/apache2/php.ini
sudo sed -i 's/^\(\s*;\?\s*\)memory_limit\s*=\s*[0-9]*M/\memory_limit = 256M/' /etc/php/$PHP_VERSION/apache2/php.ini


echo "[XDebug]
# https://xdebug.org/docs/all_settings
zend_extension = xdebug

xdebug.mode=debug
;xdebug.mode=develop
xdebug.client_port=9000

; host ip adress of wsl network adapter
xdebug.client_host=$HOST_IP

; idekey value is specific to PhpStorm
xdebug.idekey=phpstorm

// always enabling debugging slows down the web interface significantly.
// Instead prefer to enable debugging only when needed. See README.md for more information.
;xdebug.start_with_request=true
" | sudo tee /etc/php/$PHP_VERSION/apache2/conf.d/20-xdebug.ini
sudo rm /etc/php/$PHP_VERSION/cli/conf.d/20-xdebug.ini
sudo ln -s  /etc/php/$PHP_VERSION/apache2/conf.d/20-xdebug.ini /etc/php/$PHP_VERSION/cli/conf.d/20-xdebug.ini

# restart apache to apply updated config
sudo service apache2 restart

# install moodle
php $MOODLE_PARENT_DIRECTORY/moodle/admin/cli/install.php --lang=DE --wwwroot=http://localhost:$APACHE_VHOST_PORT --dataroot=$MOODLE_PARENT_DIRECTORY/moodledata --dbtype=mariadb --dbhost=$DB_HOST --dbport=3312 --dbuser=${_DB_MOODLE_USER} --dbpass=${_DB_MOODLE_PW} --dbname=${_DB_MOODLE_NAME} --fullname=fullname --shortname=shortname --adminuser=${_MOODLE_USER} --adminpass=${_MOODLE_PW} --adminemail=admin@blub.blub --supportemail=admin@blub.blub --non-interactive --agree-license

# setup for plugins (but don't download them, they have to be present in the moodle folder already)
# TODO: refactor with/for new playbook approach
# php local/declarativesetup/cli/run_playbook.php -p=adler -r=moodle_dev_env
# and role test_users
git clone https://github.com/ProjektAdLer/moodle-docker /tmp/moodle-docker
cp -r /tmp/moodle-docker/opt/adler/moodle/adler_setup $MOODLE_PARENT_DIRECTORY/moodle/
rm -rf /tmp/moodle-docker
php $MOODLE_PARENT_DIRECTORY/moodle/adler_setup/setup.php --first_run=true --user_name=${_USER_NAME} --user_password=${_USER_PASSWORD} --user_role=${_USER_ROLE}

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
\$CFG->behat_wwwroot = 'http://127.0.0.1:$APACHE_VHOST_PORT';
\$CFG->behat_prefix = 'bht_';
\$CFG->behat_dataroot = '$MOODLE_PARENT_DIRECTORY/moodledata_bht';

require_once('$MOODLE_PARENT_DIRECTORY/moodle/moodle-browser-config/init.php');
require_once(__DIR__ . '/lib/setup.php'); // Do not edit
" >> $MOODLE_PARENT_DIRECTORY/moodle/config.php

# configure cron job
echo adding cron job
echo "*/1 * * * * $WSL_USER php $MOODLE_PARENT_DIRECTORY/moodle/admin/cli/cron.php > /dev/null 2>> $MOODLE_PARENT_DIRECTORY/moodledata/moodle-cron.log" | sudo tee /etc/cron.d/moodle


cd $MOODLE_PARENT_DIRECTORY/moodle
# install composer dependencies
composer i

#clone behat test browser config repo
git clone https://github.com/andrewnicols/moodle-browser-config

# setup test environments
php admin/tool/phpunit/cli/init.php
php admin/tool/behat/cli/init.php

echo moodle login data: username: ${_MOODLE_USER} password: ${_MOODLE_PW}
echo db root password: ${_DB_ROOT_PW}
echo Host IP (for IDE config): $HOST_IP



