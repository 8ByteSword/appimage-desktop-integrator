#!/usr/bin/env bash

# Check if the script is being run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires Bash. Please run it with Bash."
    echo "You can use one of the following command to run it with Bash:"
    echo " - bash $0"
    echo " - ./$0"
    exit 1
fi

# Check if wget is installed
if ! command -v wget >/dev/null 2>&1
then
    echo "wget is not installed. Please install it and run the script again."
    exit 1
fi

# Get the directory where the script is being run
script_dir=$(pwd)

# Download the main script
wget "https://github.com/8ByteSword/appimage-launcher-generator/blob/main/install_appimages.sh" -O "$script_dir/install_appimages.sh"
chmod +x "$script_dir/install_appimages.sh"

# Check if config.ini already exists
if [ -f "$script_dir/config.ini" ]; then
    read -p "config.ini already exists. Do you want to overwrite it? [y/N] " overwrite
    case "$overwrite" in
        [yY][eE][sS]|[yY])
            # Overwrite the existing config.ini
            cat > "$script_dir/config.ini" <<EOL
icons_dir=$HOME/icons
appimages_dir=$HOME/AppImages
update_dir=$HOME/.local/share/applications
EOL
            echo "config.ini has been overwritten."
            ;;
        *)
            echo "Skipping config.ini overwrite. Using the existing file."
            ;;
    esac
else
    # Create default config file
    cat > "$script_dir/config.ini" <<EOL
icons_dir=$HOME/icons
appimages_dir=$HOME/AppImages
update_dir=$HOME/.local/share/applications
EOL
    echo "Default config.ini file created."
fi

# Determine the shell configuration file
shell_config=""
if [ -n "$BASH_VERSION" ]; then
    shell_config="$HOME/.bashrc"
elif [ -n "$ZSH_VERSION" ]; then
    shell_config="$HOME/.zshrc"
else
    echo "Unsupported shell. Please add the alias manually."
    exit 1
fi

# Add alias to the shell configuration file
echo "alias install_appimages='$script_dir/install_appimages.sh'" >> "$shell_config"
echo "Alias added to $shell_config"

# Reload the shell configuration
source "$shell_config"

echo "Installation complete. You can now use 'install_appimages' to run the script."