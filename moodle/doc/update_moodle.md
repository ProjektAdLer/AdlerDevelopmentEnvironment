# Update Moodle
⚠️ This is not an official way to update Moodle but will likely work fine as long as only files were
changed that are not part of the moodle repository (eg. plugins).

⚠️ It is not possible to downgrade Moodle. To downgrade, it is required to reset the environment (`reset_data.sh`) before starting
with the Update step.

1. **Backup**:
   Especially because this is an unsupported way to update moodle, it is important to create a full backup before updating,
   including the moodle directory itself. The `backup_data.sh` script **does not backup the moodle directory**.
2. **Update**:
    - change to the moodle directory: `cd /home/<wsl username>/moodle/moodle`
    - fetch the branch: `git fetch origin <branch name>:<branch name>`
    - checkout the branch: `git checkout <branch name>`
3. **Update the database**:
    - open Moodle in the browser and login as admin
