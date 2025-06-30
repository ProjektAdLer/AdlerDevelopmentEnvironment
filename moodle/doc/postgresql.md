# Postgresql
The `docker-compose.yml` file uses a MariaDB database.

To use Postgresql instead of MariaDB, you have to switch the database type in the `docker-compose.yml`. You could use something like this:
```yaml
services:
  pgsql_db_moodle:
    image: postgres:13
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: ${_DB_MOODLE_USER}
      POSTGRES_PASSWORD: ${_DB_MOODLE_PW}
      POSTGRES_DB: ${_DB_MOODLE_NAME}
    volumes:
      - psql_db_moodle_data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  psql_db_moodle_data:
```

As phpMyAdmin replacement you can use [Adminer](https://www.adminer.org/) which supports Postgresql.

It is configured as similar as possible to the MariaDB database.
At the moment there is no way to migrate the data between the two databases.
Take a backup of the data before switching to Postgresql, so you can restore it later.

⚠️⚠️ **Danger** ⚠️⚠️
- It is not possible to back up a Postgresql with the provided backup script.
- It is not possible to restore a backup from a MariaDB database to a Postgresql database with the provided restore script.

When switching to Postgresql, you have to modify the config.php file in the moodle folder (see the example below).
You also have to delete the content of the moodledata folder (back it up before).
Restart the apache server after installing the dependencies: `sudo systemctl restart apache2`.
```php
$CFG->dbtype    = 'pgsql';
$CFG->dblibrary = 'native';
$CFG->dbhost    = '127.0.0.1';
$CFG->dbname    = 'bitnami_moodle';
$CFG->dbuser    = 'bitnami_moodle';
$CFG->dbpass    = 'c';
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array (
    'dbpersist' => 0,
    'dbport' => 5432, // default PostgreSQL port
    'dbsocket' => '',
    'dbcollation' => 'en_US.utf8', // adjust this according to your PostgreSQL server configuration
);
```
