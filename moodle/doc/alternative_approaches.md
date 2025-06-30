# This sections covers the decision for the used approach and notes (for reference) for alternative approaches.

## Evaluation of different approaches to develop for moodle on windows
**Running moodle webserver on Windows**: All approaches where the webserver runs on Windows have the common problem that the performance is very bad.
The following variants of this approach were tested: [Moodle on Windows](https://docs.moodle.org/402/de/Vollst%C3%A4ndiges_Installationspaket_f%C3%BCr_Windows), own setup with XAMPP with database from XAMPP (DB had problem starting sometimes) and DB in WSL.

**Running moodle webserver in WSL**: This approach works well. This is the approach I followed the most time.
Windows 10 had a bug where WSL hung up regularly (probably caused by switching monitor configuration).

**Running moodle in docker**: In theory a well working approach. Should provide the same performance as the WSL approach and setup should be easier.
In practice there were too many problems with this approach.


## approach WSL
This documentation outlines the steps to set up a Moodle PHP development environment
using Windows Subsystem for Linux (WSL2) and Docker Desktop. Other potential approaches are
described and evaluated below.


### docker compose approach
These are my notes for the docker-compose approach. It never fully worked. Just here for future reference.

**IMPORTANT** Run all docker commands from inside WSL. It will not work from windows because bind mounts to WSL filesystem are broken from windows.
**NOTE** It might be required to set automatic line ending conversion to false or auto in git config. Otherwise, the scripts might not work (not yet tested).

#### prepare container
1) Disable Plugin installation in docker compose: `DEVELOP_DONT_INSTALL_PLUGINS: false`
2) Start container: `docker-compose up -d`
2) setup xdebug. Run once after container is up: `docker exec moodle-docker-moodle-1 /opt/adler/setup_xdebug.sh`. It is not save (aka tested) tun run this script multiple times.

#### setup PHPStorm
1) setup docker: Settings -> Build, Execution, Deployment -> Docker -> add new
- choose WSL
- add Mapping: /opt/bitnami/moodle (Virtual machine path) -> /home/markus/moodle/moodle (Local path)

2) setup PHP interpreter: Settings -> PHP -> CLI interpreter -> 2 dots ->
- add new -> From docker, ...
    - choose Docker compose
    - Select docker compose file
    - Select service moodle
    - press ok
- now choose
    - Lifecycle: Connect to existing container
    - again ok
- now ...
    - Path mappings -> folder icon
    - add new: not exactly sure what to add there, i think something like \\wsl$\Ubuntu\home\markus\moodle -> /bitnami/moodle \
      there is an existing mapping with the same remote path, but thats ok
    - press ok
- and ok

- set project default interpreter to new interpreter

3) Start debugging (create debug profile)

This approach uses a bind mount from the default WSL instance to the docker container. It has some disadvantages:
- PHPStorm can only modify files after changing the permissions of the moodle folder with `sudo chmod -R 777 moodle`.
  This is likely error-prone as the might be different reasons why the permissions (of some files) might change.
- Container can only be started from inside WSL. If run from windows, the bind mount will mount some other directory.

#### setup PHPStorm (alternative)
- use volume instead of bind mount
- path mapping `//wsl.localhost/docker-desktop-data/data/docker/volumes/moodle-docker_moodle_moodle/_data` -> `/bitnami/moodle`
- open `//wsl.localhost/docker-desktop-data/data/docker/volumes/moodle-docker_moodle_moodle/_data` as project in phpstorm

Problems and workarounds with this approach:
- Default open dialog can't open docker-desktop-data folder (WTF how stupid is this). \
  Workaround: Enable new dialog (Help -> Edit Custom Properties -> add `ide.ui.new.file.chooser=true` to the file)
- Terminal can't be opened in docker desktop WSL instance. \
  Workaround: Open terminal in another WSL instance. Settings -> Tools -> Terminal -> Shell path: `wsl.exe -d Ubuntu`

#### files
setup script
```bash
#!/bin/bash

xdebug_version="3.2.2"

apt update
apt-get install wget gnupg ca-certificates apt-transport-https software-properties-common -y
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
apt update
apt install -y php8.1-dev autoconf automake

mkdir /tmp/xdebug
cd /tmp/xdebug
wget https://xdebug.org/files/xdebug-${xdebug_version}.tgz
tar -xvzf xdebug-${xdebug_version}.tgz
cd xdebug-${xdebug_version}
phpize
./configure
make
cp modules/xdebug.so /opt/bitnami/php/lib/php/extensions/

{
  echo "zend_extension = xdebug"
  echo ""
  echo "; Defaults"
  echo "xdebug.default_enable=1"
  echo "xdebug.remote_enable=1"
  echo "xdebug.remote_port=9000"
  echo ""
  echo "; The Windows way"
  echo "xdebug.remote_connect_back=0"
  echo "xdebug.remote_host=127.10.0.1"
  echo ""
  echo "; idekey value is specific to PhpStorm"
  echo "xdebug.idekey=PHPSTORM"
  echo ""
  echo "; Optional: Set to true to always auto-start xdebug"
  echo "xdebug.remote_autostart=true"
} >> /opt/bitnami/php/etc/conf.d/xdebug.ini
```

docker-compose.yml

```yaml
version: '3'
services:
  #  test:
  #    image: debian
  #    command: sleep infinity
  #    volumes:
  #      - /home/markus/moodle/moodle:/moodle
  moodle:
    build:
      context: ..
      args:
        PLUGIN_VERSION: main
        MOODLE_VERSION: 4.2
    ports:
      - '8000:8080'
    environment:
      PHP_OUTPUT_BUFFERING: 8192
      PHP_POST_MAX_SIZE: 2048M
      PHP_UPLOAD_MAX_FILESIZE: 2048M
      MOODLE_DATABASE_HOST: db_moodle
      MOODLE_DATABASE_PORT_NUMBER: 3306
      MOODLE_DATABASE_USER: moodle
      MOODLE_DATABASE_PASSWORD: moodle
      MOODLE_DATABASE_NAME: moodle
      BITNAMI_DEBUG: true
      USER_NAME: student,manager
      USER_PASSWORD: Student1234!1234,Manager1234!1234
      USER_ROLE: manager,false
      DEVELOP_DONT_INSTALL_PLUGINS: true
    volumes:
      - moodle_moodle:/bitnami/moodle
      #      - /home/markus/moodle/moodle:/bitnami/moodle
      - moodle_moodledata:/bitnami/moodledata
      - moodle_moodledata_phpu:/bitnami/moodledata_phpu
    depends_on:
      - db_moodle
  #    restart: unless-stopped

  db_moodle:
    image: docker.io/bitnami/mariadb:10.6
    environment:
      MARIADB_USER: moodle
      MARIADB_PASSWORD: moodle
      MARIADB_ROOT_PASSWORD: root_pw
      MARIADB_DATABASE: moodle
      MARIADB_CHARACTER_SET: utf8mb4
      MARIADB_COLLATE: utf8mb4_unicode_ci
    volumes:
      - db_moodle_data:/bitnami/mariadb
    restart: unless-stopped

  phpmyadmin:
    image: phpmyadmin
    ports:
      - 8090:80
    environment:
      PMA_USER: root
      PMA_PASSWORD: abcd
      PMA_HOSTS: db_moodle
    restart: unless-stopped

volumes:
  moodle_moodledata_phpu:
    driver: local
  moodle_moodledata:
    driver: local
  moodle_moodle:
    driver: local
  db_moodle_data:
    driver: local
```

#### working/not working
**Known working**:
- running script from php storm -> debug works

**Known not working**:
- ~there was an overlay fs over /bitnami/moodle, therefore the files in phpstorm do not match the ones in container~ (not reproducable)
- starting docker container from windows \
  it will create a bind mount to `\\wsl.localhost\docker-desktop\tmp\docker-desktop-root\containers\services\02-docker\rootfs\home\markus\moodle` which is useless.
- PHPStorm file watcher made problems at least the 2nd scenario (volume for moodle directory)

- debugging webbrowser requests

**known problems**:
- PHPStorm runs php as root user. This causes problems with the permissions of the files. [potential workaround](https://youtrack.jetbrains.com/issue/WI-57044/Change-user-for-docker-compose-interpreter)


TODO
- automatisch berechtigungen setzen dass phpstorm die dateien bearbeiten kann
- debugging webbrowser requests
- moodle config.php debug configuration

