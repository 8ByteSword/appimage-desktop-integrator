#!/usr/bin/env bash

# Function to purge all traces of the AppImage integrator
purge_appimage_integrator() {
    echo "Purging AppImage Integrator..."

    # Remove scripts from /usr/local/bin
    sudo rm -f /usr/local/bin/install_appimages
    sudo rm -f /usr/local/bin/setup_appimage_integrator
    echo "Removed scripts from /usr/local/bin"

    # Remove the config file
    rm -f "$HOME/.config/appimage_desktop_integrator/config.ini"
    echo "Removed configuration files"

    # Remove desktop entries created by the integrator
    find "$HOME/.local/share/applications" -name "*.desktop" -exec grep -l "Generated by AppImage Integrator" {} \; -delete
    echo "Removed desktop entries created by AppImage Integrator"

    # Remove icons if desired
    rm -rf "$HOME/icons"
    echo "Removed icons directory"

    echo "Purge complete. AppImage Integrator has been removed from your system."
}


# Function to install the integrator
install_appimage_integrator() {
    # Copy the main script to /usr/local/bin
    sudo cp "$script_dir/install_appimages.sh" /usr/local/bin/install_appimages
    sudo chmod +x /usr/local/bin/install_appimages

    # Copy the setup script itself to /usr/local/bin
    sudo cp "$script_dir/setup_appimage_integrator.sh" /usr/local/bin/setup_appimage_integrator
    sudo chmod +x /usr/local/bin/setup_appimage_integrator

    

    echo "Scripts have been moved to /usr/local/bin. You can now run 'install_appimages' and 'setup_appimage_integrator' from anywhere."

    # Remove alias from shell configuration
    sed -i '/alias install_appimages/d' "$HOME/.bashrc" 2>/dev/null
    sed -i '/alias install_appimages/d' "$HOME/.zshrc" 2>/dev/null

    echo "Alias removed from shell configuration. Scripts are now accessible globally."
}


# Check if the script is being run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires Bash. Please run it with Bash."
    echo "You can use one of the following command to run it with Bash:"
    echo " - bash $0"
    echo " - ./$0"
    exit 1
fi

# Get the directory where the script is being run
script_dir=$(pwd)

# Check for --purge argument
if [ "$1" = "--purge" ]; then
    purge_appimage_integrator
    exit 0
fi

# Check if wget is installed
if ! command -v wget >/dev/null 2>&1
then
    echo "wget is not installed. Please install it and run the script again."
    exit 1
fi

# Download the main script
wget "https://raw.githubusercontent.com/8ByteSword/appimage-desktop-integrator/main/install_appimages.sh" -O "$script_dir/install_appimages.sh"
chmod +x "$script_dir/install_appimages.sh"

# Create default config file if it doesn't exist
if [ ! -f "$script_dir/config.ini" ]; then
    cat > "$script_dir/config.ini" <<EOL
icons_dir=$HOME/icons
appimages_dir=$HOME/AppImages
update_dir=$HOME/.local/share/applications
EOL
    echo "Default config.ini file created."
else
    echo "Existing config.ini file found. Skipping creation."
fi

install_appimage_integrator

echo "Installation complete. You can now use 'install_appimages' to run the script."
echo "To uninstall and remove all traces, run this script with the --purge option."
echo "This script was also added to your bin, to purge use setup_appimage_integrator --purge in any directory"