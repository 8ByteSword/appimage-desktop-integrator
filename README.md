# AppImage Desktop Integrator

This bash script automates the process of creating desktop entries with icons for AppImage applications. It simplifies the integration of AppImage apps into the desktop environment, making them easily accessible and launchable.

## Features
- Automatically creates desktop entries for AppImage files
- Extracts and sets the appropriate icon for each desktop entry
- Supports various Linux distributions
- Allows specifying custom directories for storing icons, AppImages, and desktop entries
- Provides options for verbose output and silent mode

## Prerequisites
- Linux operating system with Bash shell
- `wget` command-line utility
- `zsync` package (installed automatically if not found)

## Installation
1. Download the `install.sh` script from the repository.
2. Open a terminal and navigate to the directory where the `install.sh` script is located.
3. Make the script executable by running the following command:
   ```
   chmod +x install.sh
   ```
4. Run the installation script with the following command:
   ```
   ./install.sh
   ```
5. The script will download the main `install_appimages.sh` script, create a default configuration file, and add an alias to your shell configuration file.
6. Restart your terminal or run `source ~/.bashrc` (or `source ~/.zshrc` if using Zsh) to apply the changes.

## Usage
1. Open a terminal and navigate to the directory where the AppImage files you want to integrate are located.
2. Run the script using the `install_appimages` command followed by any desired options and AppImage file paths.
   ```
   install_appimages [options] [appimage files...]
   ```
   - If no AppImage files are provided as arguments, the script will process all AppImage files in the current directory.
   - To process specific AppImage files, provide their file paths as command-line arguments.
3. The script will process each AppImage file, create desktop entries, and extract icons.
   - By default, the desktop entries will be created in the `$HOME/.local/share/applications/` directory.
   - The extracted icons will be stored in the `icons/` folder in the current directory.
4. If a `config.ini` file is present in the same directory as the script, it will be used to override the default configuration values.

## Usage Examples

Suppose you have the following AppImage files in your `~/installations` directory:
- `AnythingLLMDesktop.AppImage`
- `LM_Studio-0.2.19.AppImage`

You can run the `update_desktop_apps.sh` script to generate the desktop entries and icons for these AppImage files.

1. Open a terminal and navigate to the `~/installations` directory:
   ```
   cd ~/installations
   ```

2. Run the script with the `-v` or `--verbose` option to enable verbose output:

   ```
   bash update_desktop_apps.sh -v
   ```

   Output:

   ```
   Icons Directory: /home/mgonzalez@depid.local/installations/icons
   AppImages Directory: /home/mgonzalez@depid.local/installations
   Desktop Entries Directory: /home/mgonzalez@depid.local/.local/share/applications
   Mounting /home/mgonzalez@depid.local/installations/AnythingLLMDesktop.AppImage...
   Mount directory: /tmp/.mount_AnythiyjVS13
   Mount PID: 2147720
   Version: 1.4.4
   Icon: /tmp/.mount_AnythiyjVS13/anythingllm-desktop.png
   .desktop entry: /home/mgonzalez@depid.local/.local/share/applications/AnythingLLMDesktop.desktop
   Mounting /home/mgonzalez@depid.local/installations/LM_Studio-0.2.19.AppImage...
   Mount directory: /tmp/.mount_LM_StuBOC1aE
   Mount PID: 2147788
   Version: 0.2.19
   Icon: /tmp/.mount_LM_StuBOC1aE/lm-studio.png
   .desktop entry: /home/mgonzalez@depid.local/.local/share/applications/LM_Studio-0.2.19.desktop
   ```

   The script mounts each AppImage file, extracts the necessary information (version and icon), and generates the corresponding `.desktop` files in the `~/.local/share/applications` directory. The extracted icons are stored in the `~/installations/icons` directory.

3. After running the script, you can verify the generated `.desktop` files:
   ```
   cat ~/.local/share/applications/AnythingLLMDesktop.desktop

   [Desktop Entry]
   Name=AnythingLLMDesktop
   Exec=/home/mgonzalez@depid.local/installations/AnythingLLMDesktop.AppImage
   Icon=/home/mgonzalez@depid.local/installations/icons/anythingllm-desktop.png
   Type=Application
   Version=1.4.4
   ```

   ```
   cat ~/.local/share/applications/LM_Studio-0.2.19.desktop

   [Desktop Entry]
   Name=LM_Studio-0.2.19
   Exec=/home/mgonzalez@depid.local/installations/LM_Studio-0.2.19.AppImage
   Icon=/home/mgonzalez@depid.local/installations/icons/lm-studio.png
   Type=Application
   Version=0.2.19
   ```

   The `.desktop` files contain the necessary information to launch the AppImage files and display their icons in the application launcher.


## Customization
The `install_appimages.sh` script provides several customization options:

- To specify a custom directory for storing icons, use the `-i` or `--icons-dir` option followed by the directory path.
  - Example: `install_appimages -i /path/to/icons/directory`

- To specify a custom directory where AppImages are stored, use the `-d` or `--appimages-dir` option followed by the directory path.
  - Example: `install_appimages -d /path/to/appimages/directory`

- To specify a custom directory for storing .desktop entries, use the `-u` or `--update-dir` option followed by the directory path.
  - Example: `install_appimages -u /path/to/desktop/entries/directory`

- To specify a custom directory for storing tools, use the `-t` or `--tools-dir` option followed by the directory path.
  - Example: `install_appimages -t /path/to/tools/directory`

- To enable verbose output, use the `-v` or `--verbose` flag.
  - Example: `install_appimages -v`

- To suppress all output messages except for errors, use the `-s` or `--silent` flag.
  - Example: `install_appimages -s`

- To display the help message and available options, use the `-h` or `--help` flag.
  - Example: `install_appimages -h`

You can also create a `config.ini` file in the same directory as the script to set default values for the following options:
- `icons_dir`: Directory to store icons (default: `$PWD/icons`)
- `appimages_dir`: Directory where AppImages are stored (default: `$PWD`)
- `update_dir`: Directory for .desktop entries (default: `$HOME/.local/share/applications`)

Example `config.ini` file:
```
icons_dir=/path/to/custom/icons/directory
appimages_dir=/path/to/custom/appimages/directory
update_dir=/path/to/custom/desktop/entries/directory
```

## License
This script is released under the [MIT License](https://opensource.org/licenses/MIT).
