#!/bin/bash

curr_dir=$(pwd)

# Function to check for updates
check_for_updates() {
    local current_version=$(cat "$HOME/.config/appimage_desktop_integrator/VERSION" 2>/dev/null || echo "0.0.0")
    local latest_version=$(wget -qO- https://raw.githubusercontent.com/8ByteSword/appimage-desktop-integrator/main/VERSION)

    if [[ "$current_version" != "$latest_version" ]]; then
        echo "A new version ($latest_version) of the script is available. Current version: $current_version"
        read -p "Do you want to update? (y/n): " update_choice
        if [[ "$update_choice" =~ ^[Yy]$ ]]; then
            wget "https://raw.githubusercontent.com/8ByteSword/appimage-desktop-integrator/main/setup_appimage_integrator.sh" -O /tmp/setup_appimage_integrator.sh
            chmod +x /tmp/setup_appimage_integrator.sh
            /tmp/setup_appimage_integrator.sh
            rm /tmp/setup_appimage_integrator.sh
            echo "Update complete. Please run 'install_appimages' again."
            exit 0
        else
            echo "Update skipped."
        fi
    else
        echo "You have the latest version ($current_version) of the script."
    fi
}

# Run update check at the beginning
check_for_updates

# Find path of directory script is located
script_path=${BASH_SOURCE[0]}
while [ -L "$script_path" ]; do
    script_dir=$( cd -P "$( dirname "$script_path" )" >/dev/null 2>&1 && pwd )
    script_path=$(readlink "$script_path")
    [[ $script_path != /* ]] && script_path=$script_dir/$script_path
done
script_dir=$( cd -P "$( dirname "$script_path" )" >/dev/null 2>&1 && pwd )

cd $curr_dir

# Default values (can be overridden by config.ini if present)
config_file="config.ini"
config_path="$script_dir"
if [ -f "$config_file" ]; then
    echo "Reading config file from: $config_file"
    source "$config_file"
elif [ -f "$config_path/$config_file" ]; then
    echo "Reading config file from: $config_path/$config_file"
    source "$config_path/$config_file"
else
    icons_dir="$PWD/icons"
    appimages_dir="$PWD"
    update_dir="$HOME/.local/share/applications"
fi
verbose=false

# Help message function
show_help() {
    echo "Usage: $0 [options] [appimage files...]"
    echo ""
    echo "Options:"
    echo "  -i, --icons-dir DIR        Specify directory to store icons."
    echo "  -d, --appimages-dir DIR    Specify directory where AppImages are stored."
    echo "  -u, --update-dir DIR       Specify directory for .desktop entries."
    echo "  -v, --verbose              Enable verbose output."
    echo "  -h, --help                 Show this help message."
}

# Default value for silent mode
silent=false

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -i|--icons-dir)
            icons_dir="$2"; shift 2;;
        -d|--appimages-dir)
            appimages_dir="$2"; shift 2;;
        -u|--update-dir)
            update_dir="$2"; shift 2;;
        -v|--verbose)
            if [ "$silent" = true ]; then
                echo "Incompatible: verbose and silent options. Ignoring verbose."
            else
                verbose=true
            fi
            shift;;
        -s|--silent)
            if [ "$verbose" = true ]; then
                echo "Incompatible: verbose and silent options. Prioritizing silent."
            fi
            verbose=false
            silent=true
            shift;;
        -h|--help)
            show_help
            exit 0;;
        --) # End of all options
            shift; break;;
        -*)
            echo "Unknown option: $1" >&2
            show_help
            exit 1;;
        *)  # No more options
            break;;
    esac
done

# Helper function for conditional echoing based on verbose and silent flags
conditional_echo() {
    if [ "$silent" = false ]; then
        echo "$@"
    fi
}


conditional_echo "Icons Directory: $icons_dir"
conditional_echo "AppImages Directory: $appimages_dir"
conditional_echo "Desktop Entries Directory: $update_dir"

# Ensure directories exist
mkdir -p "$icons_dir" "$appimages_dir" "$update_dir"

# Check if zsyncmake is installed
if ! which zsyncmake > /dev/null; then
    conditional_echo "Installing zsyncmake..."
    sudo apt-get update && sudo apt-get install -y zsync
fi

# Function to extract and process AppImage
process_appimage() {
    APPIMAGE_PATH="$1"

    if ! [ -x "$APPIMAGE_PATH" ]; then
        chmod +x "$APPIMAGE_PATH"
    fi

    # Try running the AppImage with --help to capture sandbox errors
    # DISPLAY= ensures the application doesn't try to open any GUI windows.
    DISPLAY= $APPIMAGE_PATH --help > appimage_output.txt 2>&1

    if grep -q "SUID sandbox helper binary" appimage_output.txt; then
        echo "The AppImage was aborted due to sandboxing issues. Running without sandboxing may pose security risks."
        echo "Should I try running it without sandboxing? (The desktop entry will be configured as such)"
        echo "Type 'yes' to proceed or 'no' to abort:"
        read user_consent
        if [ "$user_consent" = "yes" ]; then
            EXEC_COMMAND="$APPIMAGE_PATH --no-sandbox"
            echo "Adding --no-sandbox option due to sandbox issues."
        else
            echo "Aborted due to user choice. The AppImage may not function correctly."
            EXEC_COMMAND="$APPIMAGE_PATH"
        fi
    else
        EXEC_COMMAND="$APPIMAGE_PATH"
    fi

    # Proceed with mounting the AppImage
    if [ "$verbose" = true ]; then
        echo "Mounting $APPIMAGE_PATH..."
    fi
    $APPIMAGE_PATH --appimage-mount > mount_output.txt 2>&1 &
    MOUNT_PID=$!
    sleep 1

    if ! read mount_path < mount_output.txt; then
        echo "Failed to get mount path for $APPIMAGE_PATH."
        return 1  # Exit the function if the mount path was not captured
    fi

    export MOUNT_POINT="$mount_path"
    if [ "$verbose" = true ]; then
        echo "Mount directory: $MOUNT_POINT"
        echo "Mount PID: $MOUNT_PID"
    fi

    if [ -d "$MOUNT_POINT" ]; then
        VERSION=$(grep 'Version=' "$MOUNT_POINT"/*.desktop 2>/dev/null | cut -d '=' -f2)
        ICON=$(find "$MOUNT_POINT" -name '*.png' 2>/dev/null | head -1)
        DESKTOP_FILE=$(basename "$APPIMAGE_PATH" .AppImage).desktop
        DESKTOP_PATH="$update_dir/$DESKTOP_FILE"

        # Ensure the icons directory exists
        mkdir -p "$icons_dir"
        cp "$ICON" "$icons_dir/"

        if [ "$verbose" = true ]; then
            echo "Version: $VERSION"
            echo "Icon: $ICON"
            echo ".desktop entry: $DESKTOP_PATH"
        fi

        if [ -f "$DESKTOP_PATH" ]; then
            sed -i "s|^Icon=.*|Icon=$icons_dir/$(basename "$ICON")|" "$DESKTOP_PATH"
            sed -i "s|^Exec=.*|Exec=$EXEC_COMMAND|" "$DESKTOP_PATH"
            sed -i "s|^Version=.*|Version=$VERSION|" "$DESKTOP_PATH"
        else
            cat > "$DESKTOP_PATH" <<EOL
[Desktop Entry]
Name=$(basename "$APPIMAGE_PATH" .AppImage)
Exec="$EXEC_COMMAND"
Icon=$icons_dir/$(basename "$ICON")
Type=Application
Version=$VERSION
EOL
        fi
    else
        echo "Failed to access mount point directory for $APPIMAGE_PATH."
        return 1
    fi

    # Cleanup
    kill $MOUNT_PID
    sleep 1
}


# Process AppImage files provided as command-line arguments or in the current directory
if [ $# -eq 0 ]; then
    # Iterate over all AppImage files in the current directory
    appimage_files=("$appimages_dir"/*.AppImage)
    if [ ${#appimage_files[@]} -eq 0 ]; then
        echo "No AppImage files found in the current directory."
    else
        for appimage in "${appimage_files[@]}"; do
            appimage_file=$(basename $appimage)
            mv $appimage $appimages_dir
            process_appimage "$appimages_dir/$appimage_file"
        done
    fi
else
    # Process AppImage files provided as command-line arguments
    for appimage in "$@"; do
        if [ -f "$appimage" ]; then
            appimage_file=$(basename $appimage)
            mv $appimage $appimages_dir
            process_appimage "$appimages_dir/$appimage_file"
        else
            echo "File not found: $appimage"
        fi
    done
fi

update-desktop-database $update_dir
