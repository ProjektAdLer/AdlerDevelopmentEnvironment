# Change Moodle <-> PHP version to install
Only follow this guide if you have some linux experience. You will likely switch Distros or add a custom PHP PPA to your
system if you want to follow this guide. Therefore you will have to expect problems as this diverging from the default
setup.

Preferably do the following **before** running the scripts the first time on a WSL instance and then don't change them 
anymore.

First find a compatible set of PHP and Moodle versions.
1) Look up PHP version compatibility of moodle in the [moodle docs](https://moodledev.io/general/development/policies/php)
2) Check Plugin compatibility with PHP and Moodle versions
   1) Find the list of all plugins in the [plugin-releases.json](https://github.com/ProjektAdLer/moodle-docker/blob/main/plugin-releases.json) \
      The array "main" is the relevant release set
   2) Check the Readme of each Plugin for compatibility information
3) Check the available PHP versions in your WSL instance, e.g. with `apt-cache search php`

Next modify the setup scripts:
1) Change the PHP version (variable `PHP_VERSION`) in the [setup.sh](../setup.sh) script