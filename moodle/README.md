# Moodle dev env

## Requirements
- WSL2 with Distro **Ubuntu 24.04**
  ⚠️ Other Distros likely will not work out of the box as of dependency issues.
- Docker Desktop

## Warnings / Hints
- To resolve any issues with shell scripts (typically ^M errors), disable automatic line ending conversion in git by running:
`git config --global core.autocrlf input`
The repo has to be cloned again after this change.

## Preparations
This section will describe how to set up and reset the development environment.

1. Enter WSL. This guide will use shell commands and therefore does not work with the Windows console.
2. Clone this repository to a place of your choice (eg `/home/<wsl username>/AdlerDevelopmentEnvironment`).
3. continue with the following sections

## Install Moodle
1) Run the `setup.sh` script as non-root user. 
   - For using an existing MariaDB database without using Docker, see [Using Existing Database](doc/existing_database.md)
2) Plugins: Clone all plugins to their corresponding directory. See the 
     [Adler LMS -> plugins.json](https://github.com/ProjektAdLer/MoodleAdlerLMS/blob/main/plugins.json) for a list of all plugins and [Moodle documentation](https://moodledev.io/docs/4.1/apis/plugintypes) for the target directories
     to clone it to. Example command: `git clone <git url> local/adler`
     - Note for playbook_adler: playbooks are subplugins of local_declarativesetup. The plugin directory is `local/declarativesetup/playbook`
3) Run adler playbook `DECLARATIVE_SETUP_MANAGER_PASSWORD='Manager1234!1234' DECLARATIVE_SETUP_STUDENT_PASSWORD='Student1234!1234' php local/declarativesetup/cli/run_playbook.php -p=adler -r=test_users,moodle_dev_env`

## Start Development Server

**Note:** The PHP built-in server (`php -S`) is slower compared to a full web server. For better performance, consider using a full web server like Caddy or Apache. See [Alternative Web Server Setup](doc/webserver_setup.md) for detailed instructions.

After completing the installation above, start the development server:

```bash
cd ~/moodle/moodle && php -S localhost:5080
```

Press `Ctrl+C` to stop the server.

## Access Moodle
- After starting the server, Moodle is available at [http://localhost:5080](http://localhost:5080)
- Default credentials can be taken from [.env](.env) file.

## Reset environment

To reset the environment and start fresh, manually delete the following:


0. Create a backup using the provided backup script: `backup_data.sh`
1. **Database**: 
  1. If using docker (default): Stop and remove Docker containers and volumes: `docker compose down -v`
  2. If using another database server: Drop the Moodle database
2. **Moodle data directories**: clear the Moodle data directories:
   - `rm -rf ~/moodle/moodledata`
   - `rm -rf ~/moodle/moodledata_bht`
   - `rm -rf ~/moodle/moodledata_phpu` 
3. **Moodle config**: delete the Moodle configuration file `config.php`

After this cleanup, you can run the setup script again.

### backup and restore scripts
- [backup_data.sh](backup_data.sh): Creates a backup of Moodle data and database. Run using ./backup_data.sh.
- [restore_data.sh](restore_data.sh): Restores Moodle from a backup. Use it like ./restore_data.sh /path/to/backup.

## Configure development and test tools
The previous steps did just set up the base moodle environment. The following guides will help configuring test and
debug tools.

### Debugging
- [Setup PHPStorm for debugging](doc/debug/configure_phpstorm.md)
- [Windows Firewall Configuration](doc/debug/windows_firewall_setup.md)
  Without this it is not possible for any IDE on Windows to connect to the xdebug server in WSL.
- [Debug Code executed in the shell](doc/debug/command_line_debug.md)

### Testing
- [Behaviour (behat) tests](doc/behat_tests.md)


## Further manuals/instructions
- [Update Moodle](doc/update_moodle.md)
- [Change Moodle <-> PHP version to install](doc/change_moodle_php_version.md)
- [Use Postgresql instead of MariaDB](doc/postgresql.md)
- [Use existing MariaDB database instead of Docker](doc/existing_database.md)
- [Evaluation of different approaches to set up this Moodle development environment](doc/alternative_approaches.md)
- [Use web server instead of php -S](doc/webserver_setup.md)

