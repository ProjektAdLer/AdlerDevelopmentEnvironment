# Configuring Moodle Behat Tests in Windows Subsystem for Linux (WSL)

This documentation outlines the approach I followed to set up Behat tests for Moodle within the WSL environment. It's designed to facilitate the running of UI applications using WSLg, crucial for executing Behat tests that require a graphical user interface.

## Prerequisites
- Ensure WSLg (Windows Subsystem for Linux with GUI support) is enabled to run UI applications in WSL. This feature is necessary for executing tests that involve a graphical user interface.

## Setup Instructions
Read the [Moodle setup guide for Behat](https://moodledev.io/general/development/tools/behat/running) to understand the requirements and setup steps for Behat tests.

1. **Selenium with Chrome:**
    - Attempts to use Selenium with Firefox resulted in errors related to user profile creation.
    - **Chrome Setup:**
        - chromedriver:
            - Download [chromedriver](https://getwebdriver.com/chromedriver#stable) version.
            - Extract the downloaded chromedriver archive and place the chromedriver file in the moodle root directory.
        - Chrome:
            - Download the [corresponding version of Chrome](http://mirror.cs.uchicago.edu/google-chrome/pool/main/g/google-chrome-stable/).
            - Install Chrome using the following command:
                ```bash
                sudo apt install -y ./<filename of the downloaded Chrome package>
                ```
            - Prevent Chrome from updating by running the following command (as unintended updates will break compatibility with chromedriver):
                ```bash
                sudo apt-mark hold google-chrome-stable
                ```
            - Run `google-chrome-stable` to verify the setup. If a Chrome window opens, the setup was successful.

2. **Download Selenium Server:**
    - Download the latest `Selenium Server (Grid)` jar file from the [official Selenium website](https://www.selenium.dev/downloads/).
    - Place it in the moodle root directory.

## Running Tests

1) navigate to the moodle root directory `cd /home/<wsl username>/moodle/moodle`
2) start Selenium: `PATH=./:$PATH java -jar <filename of the downloaded selenium file> standalone`
3) in a new terminal window, run the following command to start the Behat test:
    ```bash
    vendor/bin/behat --config /home/<wsl username>/moodle/moodledata_bht/behatrun/behat/behat.yml --profile chrome
    ```
   This is just for testing, it will run all moodle tests. After some tests a Chrome window will open (not all tests actually need
   a browser). If this happens the tests are running correctly.

## Adding a new feature (.feature file)
After adding a new feature file, behat test environment has to be recreated. This can be done by running the following command:
`php admin/tool/behat/cli/init.php`