# Using Existing Database

This guide explains how to use the Moodle development environment with an existing MariaDB database instead of the Docker-based database.

## Configuration

### Environment Variables

Configure your database credentials in the `.env` file:

```bash
# Database configuration for existing MariaDB
_DB_ROOT_PW=your_root_password
_DB_MOODLE_USER=moodle_user
_DB_MOODLE_PW=moodle_password
_DB_MOODLE_NAME=moodle_database
```

### Command Line Parameters

All scripts support the following parameters for database configuration:

- `--skip-docker` or `-s`: Skip Docker setup and use existing database
- `--dbhost HOST` or `-d HOST`: Database host (default: 127.0.0.1)
- `--dbport PORT` or `-p PORT`: Database port (default: 3312 for Docker, 3306 for everything else)

### Usage Examples: Setup with Remote MariaDB

```bash
# Use remote MariaDB server
./setup.sh --skip-docker --dbhost 192.168.1.100

# Use remote MariaDB with custom port
./setup.sh --skip-docker --dbhost 192.168.1.100 --dbport 3307
```

## Database Setup

*Note: Database setup instructions will be added to this section in the future.*

