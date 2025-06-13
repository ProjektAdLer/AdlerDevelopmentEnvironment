# Alternative Web Server Setup

The default setup uses PHP's built-in development server (`php -S`), which can be slower for development. This guide shows how to set up alternative web servers for better performance.

All servers will serve Moodle at [http://localhost:5080](http://localhost:5080) once configured.

## PHP Built-in Server (Default)

```bash
cd ~/moodle && php -S localhost:5080
```

## Caddy Web Server

This is a in between solution between the PHP built-in server and a full web server like Apache or Nginx. It is easier to set up than Apache, but should still provide better performance than the PHP built-in server.

### Prerequisites

Install PHP-FPM:
```bash
sudo apt install php-fpm
```

### Installation

1. Install Caddy:
```bash
sudo apt install caddy
```

2. Stop and disable the default Caddy service:
```bash
sudo systemctl stop caddy && sudo systemctl disable caddy
```

3. Create a `Caddyfile` in your moodle directory:
```bash
cd ~/moodle
cat > Caddyfile << 'EOF'
:5080
root * <full path to your moodle folder eg /a/b/moodle/>
php_fastcgi unix//run/php/php-fpm.sock
file_server
EOF
```

### Running Caddy

Start Caddy from your moodle directory:
```bash
cd ~/moodle
sudo caddy run
```

sudo is required to use the php-fpm socket. It should be possible to solve it without the need of sudo.

## Apache Web Server

More complex to set up and requires lots of changes to the system, potentially beeing in conflict with other services.

Provides the best performance.

### Installation

1. Install Apache and PHP modules:
```bash
sudo apt install -y apache2 php libapache2-mod-php
```

2. Enable necessary Apache modules:
```bash
sudo a2enmod rewrite
sudo a2enmod php8.3  # adjust version as needed
```

### Configuration

1. Create a virtual host configuration:
```bash
sudo tee /etc/apache2/sites-available/moodle.conf << 'EOF'
<VirtualHost *:5080>
    DocumentRoot PATH_TO_MOODLE_FOLDER
    <Directory PATH_TO_MOODLE_PARENT_FOLDER>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/moodle_error.log
    CustomLog ${APACHE_LOG_DIR}/moodle_access.log combined
</VirtualHost>
EOF
```
Replace PATH_TO_MOODLE_FOLDER and PATH_TO_MOODLE_PARENT_FOLDER. First is the absolute path to the moodle folder and the second the full parth to the folder containing the directories moodle, moodledata, moodledata_*

2. Enable the virtual host:
```bash
sudo a2ensite moodle.conf
```

3. Add the custom port to ports.conf:
```bash
echo "Listen 5080" | sudo tee -a /etc/apache2/ports.conf
```

4. Set up proper permissions (using ACLs for shared access):
```bash
WSL_USER=$(whoami)
MOODLE_PARENT_DIRECTORY=$(getent passwd $WSL_USER | cut -d: -f6)

# Set ACLs to ensure both users have proper permissions
sudo setfacl -m u:www-data:rx "$MOODLE_PARENT_DIRECTORY"
for dir in moodle moodledata moodledata_phpu moodledata_bht; do
    if [ -d "$MOODLE_PARENT_DIRECTORY/$dir" ]; then
        sudo setfacl -R -m u:$WSL_USER:rwx,u:www-data:rwx,m::rwx "$MOODLE_PARENT_DIRECTORY/$dir"
        sudo setfacl -R -d -m u:$WSL_USER:rwx,u:www-data:rwx,m::rwx "$MOODLE_PARENT_DIRECTORY/$dir"
    fi
done
```

Note: You might still run into permission errors. These should be files where moodle explicitly sets permissions (like session files). You can safely delete them. This will log you out of your local moodle. Just log in again.

5. Restart Apache to apply changes:
```bash
sudo service apache2 restart
```

### Running Apache

Apache is running gas a service. It is already running. You can control it via `systemctl start|stop|restart|status apache2`.
