# PHPStorm setup
0. **Make sure, moodle is installed via the installation script**
1. **WSL PHP Interpreter**:
- Navigate to Settings -> PHP -> CLI interpreter
- Click 3 dots -> "+" -> From Docker, Vagrant, ... -> WSL
- Choose your WSL2 distribution and press OK
- Set Configuration options (folder button on the right) xdebug.client_host -> <ip of WSL default gateway> (printed at
  the end of the setup script, can also be found with `ip route | grep default | awk '{print $3}'` inside WSL)

2. **Set new interpreter as project default**:
- Ctrl + Shift + A -> Change PHP interpreter
- Choose new interpreter -> OK

3. **PHP Server Setup**:
- Navigate to Settings -> PHP -> Servers -> localhost
- On the first incoming debugging connection, this entry should be created. If not, add it manually (Host: localhost, Port: 5080, Debugger: Xdebug).
- Check "Use path mappings (...)"
- Add the following path mapping (adjust name of WSL distribution and username):
  `\\wsl$\\<wsl distribution name>\\home\\<wsl username>\\moodle\\moodle -> /home/<wsl username>/moodle/moodle`

4. Make sure that the moodle phpunit.xml file (...\moodle\moodle\phpunit.xml) is selected: 
   Settings -> PHP -> Test Frameworks -> Default configuration file