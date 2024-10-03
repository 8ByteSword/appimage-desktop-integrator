#!/bin/bash

# Function to check if running as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi
}

# Function to fix AppImage permissions
fix_appimage_permissions() {
    local appimage_path="$1"
    chmod +x "$appimage_path"
    echo "AppImage permissions fixed."
}

# Function to disable AppImage sandboxing
disable_sandboxing() {
    local appimage_path="$1"
    sed -i 's|AI_EXEC="$APPDIR/$APPIMAGE_BINARY"|AI_EXEC="$APPDIR/$APPIMAGE_BINARY --no-sandbox"|g' "$appimage_path"
    echo "Sandboxing disabled for the AppImage."
}

# Main execution
check_root

echo "AppImage Troubleshooting Script"
echo "==============================="

read -p "Enter the full path to your AppImage: " appimage_path

if [ ! -f "$appimage_path" ]; then
    echo "Error: AppImage not found at the specified path."
    exit 1
fi

fix_appimage_permissions "$appimage_path"
disable_sandboxing "$appimage_path"

echo "Troubleshooting complete. Try running your AppImage now."
