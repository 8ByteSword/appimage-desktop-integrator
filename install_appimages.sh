#!/bin/bash

# Version info
CURRENT_VERSION="2.0.2"

# Common locations where AppImages might be found
COMMON_APPIMAGE_LOCATIONS=(
    "$HOME/Downloads"
    "$HOME/Desktop"
    "$HOME/Applications"
    "$HOME/apps"
    "$HOME/AppImages"
    "$HOME/.local/bin"
    "$HOME/bin"
    "/opt"
)

# Set script directory
curr_dir=$(pwd)
script_path=${BASH_SOURCE[0]}
while [ -L "$script_path" ]; do
    script_dir=$( cd -P "$( dirname "$script_path" )" >/dev/null 2>&1 && pwd )
    script_path=$(readlink "$script_path")
    [[ $script_path != /* ]] && script_path=$script_dir/$script_path
done
script_dir=$( cd -P "$( dirname "$script_path" )" >/dev/null 2>&1 && pwd )

# Initialize with minimal config for quick commands
init_minimal_config() {
    config_path="$HOME/.config/appimage_desktop_integrator"
    if [ -f "$config_path/config.ini" ]; then
        source "$config_path/config.ini"
        
        # Handle old config format (single appimages_dir)
        if [ -n "$appimages_dir" ] && [ -z "$appimages_dirs" ]; then
            appimages_dirs=("$appimages_dir")
        fi
        
        # Ensure appimages_dirs is an array
        if [ -z "$appimages_dirs" ]; then
            appimages_dirs=("$HOME/AppImages" "$HOME/Applications")
        fi
    else
        icons_dir="$HOME/.local/share/icons/appimage-integrator"
        appimages_dirs=("$HOME/AppImages" "$HOME/Applications")
        update_dir="$HOME/.local/share/applications"
    fi
    
    # Always ensure directories exist (regardless of config file presence)
    if ! [ -d "$update_dir" ]; then
        mkdir -p "$update_dir"
    fi
    if ! [ -d "$icons_dir" ]; then
        mkdir -p "$icons_dir"
    fi
}

# Show current configuration and status
show_status() {
    init_minimal_config
    echo "AppImage Desktop Integrator - Current Status"
    echo "==========================================="
    echo ""
    echo "Configuration:"
    echo "  Config file: $config_path/config.ini"
    echo "  Icons stored in: $icons_dir"
    echo "  Desktop entries in: $update_dir"
    echo "  AppImage directories monitored:"
    for dir in "${appimages_dirs[@]}"; do
        if [ -d "$dir" ]; then
            count=$(find "$dir" -name "*.AppImage" 2>/dev/null | wc -l)
            echo "    - $dir ($count AppImages)"
        else
            echo "    - $dir (not created yet)"
        fi
    done
    echo ""
    
    # Count installed AppImages
    local installed_count=0
    for desktop_file in "$update_dir"/*.desktop; do
        if [ -f "$desktop_file" ]; then
            # Check if it's an AppImage desktop file (more flexible detection)
            exec_line=$(grep "^Exec=" "$desktop_file" 2>/dev/null || true)
            if [[ "$exec_line" == *".AppImage"* ]]; then
                ((installed_count++))
            fi
        fi
    done
    echo "Integrated AppImages: $installed_count"
    echo ""
    echo "Quick tips:"
    echo "  - Run 'ai' for short commands (alias for install_appimages)"
    echo "  - Run 'ai find' to search for AppImages on your system"
    echo "  - Run 'ai install' to install from common locations"
    echo "  - Tab completion available: ai <TAB>"
}

# Find AppImages on the system
find_appimages() {
    echo "Searching for AppImages on your system..."
    echo "========================================="
    echo ""
    
    local found_any=false
    local all_appimages=()
    
    for location in "${COMMON_APPIMAGE_LOCATIONS[@]}"; do
        if [ -d "$location" ]; then
            appimages=($(find "$location" -maxdepth 2 -name "*.AppImage" 2>/dev/null))
            if [ ${#appimages[@]} -gt 0 ]; then
                found_any=true
                echo "Found in $location:"
                for app in "${appimages[@]}"; do
                    # Check if already integrated
                    basename_app=$(basename "$app")
                    if desktop_file_exists "$basename_app"; then
                        echo "  ✓ $basename_app (already integrated)"
                    else
                        echo "  - $basename_app"
                        all_appimages+=("$app")
                    fi
                done
                echo ""
            fi
        fi
    done
    
    if [ "$found_any" = false ]; then
        echo "No AppImages found in common locations."
        echo ""
        echo "Tip: Place your AppImages in one of these directories:"
        for location in "${COMMON_APPIMAGE_LOCATIONS[@]}"; do
            echo "  - $location"
        done
    else
        if [ ${#all_appimages[@]} -gt 0 ]; then
            echo "Would you like to integrate the unintegrated AppImages? (y/n)"
            read -p "> " integrate_choice
            if [[ "$integrate_choice" =~ ^[Yy]$ ]]; then
                for app in "${all_appimages[@]}"; do
                    echo ""
                    echo "Integrating: $(basename "$app")"
                    install_single_appimage "$app"
                done
            fi
        fi
    fi
}

# Check if desktop file exists for an AppImage
desktop_file_exists() {
    local appimage_name="$1"
    local base_name="${appimage_name%.AppImage}"
    
    for desktop_file in "$update_dir"/*.desktop; do
        if [ -f "$desktop_file" ]; then
            # More flexible check - look for the AppImage in Exec line
            if grep -q "$base_name.*\.AppImage" "$desktop_file" 2>/dev/null; then
                return 0
            fi
        fi
    done
    return 1
}

# Install a single AppImage with better UX
install_single_appimage() {
    local appimage_path="$1"
    local original_path=$(dirname "$appimage_path")
    local appimage_name=$(basename "$appimage_path")
    
    # Check if original_path is a valid path (not .)
    # If not change to $PWD
    if [ "$original_path" = "." ]; then
        original_path=$PWD
    fi
    
    # Ask where to install
    echo "Where would you like to store this AppImage?"
    echo "Available directories:"
    local i=1
    for dir in "${appimages_dirs[@]}"; do
        echo "  $i) $dir"
        ((i++))
    done
    echo "  $i) Custom location"
    echo "  0) Keep in current location ($original_path)"
    
    read -p "Choice (default: 1): " choice
    choice=${choice:-1}
    
    local target_dir
    if [ "$choice" = "0" ]; then
        target_dir="$original_path"
    elif [ "$choice" = "$i" ]; then
        read -p "Enter custom directory: " target_dir
        # Add to appimages_dirs for future use
        appimages_dirs+=("$target_dir")
    else
        target_dir="${appimages_dirs[$((choice-1))]}"
    fi
    
    # Create directory if needed
    mkdir -p "$target_dir"
    
    # Move or copy the AppImage
    if [ "$original_path" != "$target_dir" ]; then
        echo "Moving $appimage_name to $target_dir..."
        mv "$appimage_path" "$target_dir/"
    fi
    # Always update the path to ensure it's correct
    appimage_path="$target_dir/$appimage_name"
    
    # Process the AppImage
    process_appimage "$appimage_path"
}

# List installed AppImages with more info
list_installed_appimages() {
    echo "Integrated AppImages"
    echo "==================="
    echo ""
    
    local count=0
    for desktop_file in "$update_dir"/*.desktop; do
        if [ -f "$desktop_file" ]; then
            # Check if it's an AppImage desktop file
            exec_line=$(grep "^Exec=" "$desktop_file" 2>/dev/null || true)
            if [[ "$exec_line" == *".AppImage"* ]]; then
                ((count++))
                name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
                # Extract actual AppImage path from exec line (handle wrapper script)
                exec_path=$(echo "$exec_line" | cut -d'=' -f2- | sed 's/"//g')
                # If using wrapper, extract the actual AppImage path
                if [[ "$exec_path" == *"appimage-run-wrapper.sh"* ]]; then
                    exec_path=$(echo "$exec_path" | sed 's|.*/appimage-run-wrapper.sh ||' | sed 's/ --no-sandbox//')
                else
                    exec_path=$(echo "$exec_path" | sed 's/ --no-sandbox//')
                fi
                version=$(grep "^Version=" "$desktop_file" | cut -d'=' -f2)
                
                echo "$count. $name"
                echo "   Version: ${version:-unknown}"
                echo "   Location: $exec_path"
                echo "   Desktop file: $desktop_file"
                
                if [ ! -f "$exec_path" ]; then
                    echo "   ⚠️  WARNING: AppImage file missing!"
                fi
                
                # Check if managed by our tool
                if grep -q "Generated by AppImage Integrator" "$desktop_file" 2>/dev/null; then
                    echo "   ✓ Managed by AppImage Integrator"
                else
                    echo "   ℹ️  Not managed by AppImage Integrator (can still remove/update)"
                fi
                echo ""
            fi
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo "No AppImages integrated yet."
        echo ""
        echo "Tips:"
        echo "  - Run 'ai find' to search for AppImages"
        echo "  - Run 'ai install <file.AppImage>' to integrate an AppImage"
        echo "  - Run 'ai help' for all commands"
    fi
}

# Show desktop files
show_desktop_files() {
    echo "Desktop Files for AppImages"
    echo "==========================="
    echo ""
    
    local found=false
    for desktop_file in "$update_dir"/*.desktop; do
        if [ -f "$desktop_file" ]; then
            # Check if it's an AppImage desktop file
            if grep -q "\.AppImage" "$desktop_file" 2>/dev/null; then
                found=true
                echo "=== $desktop_file ==="
                cat "$desktop_file"
                echo ""
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        echo "No AppImage desktop files found."
    fi
}

# View logs for an AppImage
view_logs() {
    local app_name="$1"
    local logs_dir="$HOME/.config/appimage_desktop_integrator/logs"
    
    if [ -z "$app_name" ]; then
        echo "Usage: ai logs <AppName>"
        echo ""
        echo "Available AppImages with logs:"
        for desktop_file in "$update_dir"/*.desktop; do
            if [ -f "$desktop_file" ] && grep -q "\.AppImage" "$desktop_file" 2>/dev/null; then
                name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
                base_name=$(basename "$desktop_file" .desktop)
                log_file="$logs_dir/${base_name}.log"
                if [ -f "$log_file" ]; then
                    echo "  - $name"
                fi
            fi
        done
        return
    fi
    
    # Find the AppImage (case-insensitive)
    local found=false
    for desktop_file in "$update_dir"/*.desktop; do
        if [ -f "$desktop_file" ] && grep -q "\.AppImage" "$desktop_file" 2>/dev/null; then
            name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
            # Case-insensitive comparison
            if [[ "${name,,}" == *"${app_name,,}"* ]]; then
                found=true
                base_name=$(basename "$desktop_file" .desktop)
                log_file="$logs_dir/${base_name}.log"
                
                if [ -f "$log_file" ]; then
                    echo "Showing logs for $name"
                    echo "Log file: $log_file"
                    echo "=================================="
                    # Show last 50 lines by default
                    tail -n 50 "$log_file"
                    echo ""
                    echo "Tip: Use 'tail -f $log_file' to follow logs in real-time"
                else
                    echo "No logs found for $name"
                    echo "The application hasn't been run yet or logging is not enabled."
                fi
                return
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        echo "No AppImage found matching: $app_name"
    fi
}

# Run an AppImage with live output
run_appimage() {
    local app_name="$1"
    if [ -z "$app_name" ]; then
        echo "Usage: ai run <AppName>"
        echo ""
        echo "Available AppImages:"
        for desktop_file in "$update_dir"/*.desktop; do
            if [ -f "$desktop_file" ] && grep -q "\.AppImage" "$desktop_file" 2>/dev/null; then
                name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
                echo "  - $name"
            fi
        done
        return
    fi
    
    # Find the AppImage (case-insensitive)
    for desktop_file in "$update_dir"/*.desktop; do
        if [ -f "$desktop_file" ] && grep -q "\.AppImage" "$desktop_file" 2>/dev/null; then
            name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
            if [[ "${name,,}" == *"${app_name,,}"* ]]; then
                exec_line=$(grep "^Exec=" "$desktop_file" | cut -d'=' -f2)
                # Remove any wrapper script reference
                exec_path=$(echo "$exec_line" | sed 's|.*/appimage-run-wrapper.sh ||' | sed 's/"//g')
                echo "Running $name..."
                echo "Press Ctrl+C to stop"
                echo "=================================="
                eval "$exec_path"
                return
            fi
        fi
    done
    
    echo "No AppImage found matching: $app_name"
}

# Debug/verbose run an AppImage
debug_appimage() {
    local app_name="$1"
    if [ -z "$app_name" ]; then
        echo "Usage: ai debug <AppName>"
        echo ""
        echo "Available AppImages:"
        for desktop_file in "$update_dir"/*.desktop; do
            if [ -f "$desktop_file" ] && grep -q "\.AppImage" "$desktop_file" 2>/dev/null; then
                name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
                echo "  - $name"
            fi
        done
        return
    fi
    
    # Find the AppImage (case-insensitive)
    for desktop_file in "$update_dir"/*.desktop; do
        if [ -f "$desktop_file" ] && grep -q "\.AppImage" "$desktop_file" 2>/dev/null; then
            name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
            if [[ "${name,,}" == *"${app_name,,}"* ]]; then
                exec_line=$(grep "^Exec=" "$desktop_file" | cut -d'=' -f2-)
                # Extract AppImage path, removing wrapper and quotes
                if [[ "$exec_line" == *"appimage-run-wrapper.sh"* ]]; then
                    # Extract path after wrapper, handling quotes properly
                    appimage_path=$(echo "$exec_line" | sed 's|.*appimage-run-wrapper.sh" "||' | sed 's|".*||')
                else
                    # Direct AppImage path
                    appimage_path=$(echo "$exec_line" | sed 's/"//g' | awk '{print $1}')
                fi
                
                echo "=== Debug Mode for $name ==="
                echo "AppImage: $appimage_path"
                echo ""
                echo "Environment variables that affect AppImages:"
                echo "  APPIMAGE_EXTRACT_AND_RUN=1  - Extract and run (for FUSE issues)"
                echo "  APPDIR                      - AppImage mount directory"
                echo "  APPIMAGE                    - Path to the AppImage"
                echo "  APPIMAGE_DEBUG=1            - Enable debug logging in wrapper"
                echo "  APPIMAGE_VERBOSE=1          - Enable verbose output"
                echo ""
                echo "You can also run with environment variables:"
                echo "  APPIMAGE_DEBUG=1 ai run $app_name"
                echo ""
                echo "Running with verbose output..."
                echo "Press Ctrl+C to stop"
                echo "=================================="
                
                # Common debug flags for different types of apps
                local debug_flags=""
                
                # Electron apps
                if [[ "${name,,}" =~ (via|vscode|discord|slack|teams|obsidian|element) ]]; then
                    debug_flags="--verbose --enable-logging --log-level=verbose"
                    echo "Detected Electron app, using flags: $debug_flags"
                fi
                
                # Qt/KDE apps
                if [[ "${name,,}" =~ (qt|kde) ]]; then
                    export QT_LOGGING_RULES="*=true"
                    echo "Enabled Qt verbose logging"
                fi
                
                # GTK apps
                if [[ "${name,,}" =~ (gtk|gnome) ]]; then
                    export GTK_DEBUG=all
                    echo "Enabled GTK debug output"
                fi
                
                # Run with strace for system calls (optional)
                read -p "Run with strace for system call tracing? (y/n): " use_strace
                if [[ "$use_strace" =~ ^[Yy]$ ]]; then
                    if command -v strace >/dev/null 2>&1; then
                        echo "Running with strace..."
                        echo "Note: strace may cause FUSE mount issues with AppImages."
                        echo "If you see 'Cannot mount AppImage', try running without strace."
                        echo ""
                        # Try with APPIMAGE_EXTRACT_AND_RUN for better strace compatibility
                        APPIMAGE_EXTRACT_AND_RUN=1 strace -e trace=open,openat,access,stat,execve -f "$appimage_path" $debug_flags 2>&1
                    else
                        echo "strace not installed. Install with: sudo apt install strace"
                        "$appimage_path" $debug_flags
                    fi
                else
                    # Run with debug flags
                    "$appimage_path" $debug_flags
                fi
                
                return
            fi
        fi
    done
    
    echo "No AppImage found matching: $app_name"
}

# Create logging wrapper script
create_logging_wrapper() {
    local wrapper_dir="$HOME/.config/appimage_desktop_integrator/bin"
    local wrapper_script="$wrapper_dir/appimage-run-wrapper.sh"
    
    mkdir -p "$wrapper_dir"
    
    cat > "$wrapper_script" <<'EOL'
#!/bin/bash
# AppImage logging wrapper

# Get the AppImage path and name
APPIMAGE_PATH="$1"
shift
APPIMAGE_NAME=$(basename "$APPIMAGE_PATH" .AppImage)

# Set up logging
LOGS_DIR="$HOME/.config/appimage_desktop_integrator/logs"
mkdir -p "$LOGS_DIR"
LOG_FILE="$LOGS_DIR/${APPIMAGE_NAME}.log"

# Check for debug mode
if [ "$APPIMAGE_DEBUG" = "1" ] || [ "$APPIMAGE_VERBOSE" = "1" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting $APPIMAGE_NAME in DEBUG mode" | tee -a "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Command: $APPIMAGE_PATH $@" | tee -a "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Environment:" | tee -a "$LOG_FILE"
    env | grep -E "(APPIMAGE|PATH|HOME|DISPLAY|WAYLAND)" | tee -a "$LOG_FILE"
    echo "================================" | tee -a "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting $APPIMAGE_NAME" >> "$LOG_FILE"
fi

# Run the AppImage with logging
if [ "$APPIMAGE_DEBUG" = "1" ]; then
    # Full debug with stderr
    "$APPIMAGE_PATH" "$@" 2>&1 | tee -a "$LOG_FILE"
else
    # Normal logging
    "$APPIMAGE_PATH" "$@" 2>&1 | tee -a "$LOG_FILE"
fi
EXIT_CODE=${PIPESTATUS[0]}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Exited with code $EXIT_CODE" >> "$LOG_FILE"

exit $EXIT_CODE
EOL
    
    chmod +x "$wrapper_script"
    echo "$wrapper_script"
}

# Upgrade existing installations to use logging
upgrade_to_v2() {
    echo "Upgrading AppImage Integrator to version 2.0"
    echo "==========================================="
    echo ""
    echo "This upgrade will:"
    echo "  - Add logging support to all integrated AppImages"
    echo "  - Enable case-insensitive search in commands"
    echo "  - Add new 'run' command for live output"
    echo ""
    
    read -p "Continue with upgrade? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Upgrade cancelled."
        return
    fi
    
    # Create logging wrapper
    wrapper_script=$(create_logging_wrapper)
    
    # Verify wrapper is executable
    if [ ! -x "$wrapper_script" ]; then
        echo "Error: Failed to create executable wrapper script"
        return 1
    fi
    
    # Update all existing desktop files
    local updated=0
    local failed=0
    for desktop_file in "$update_dir"/*.desktop; do
        if [ -f "$desktop_file" ] && grep -q "\.AppImage" "$desktop_file" 2>/dev/null; then
            # Skip if already using wrapper
            if grep -q "appimage-run-wrapper.sh" "$desktop_file" 2>/dev/null; then
                continue
            fi
            
            # Get current exec line
            exec_line=$(grep "^Exec=" "$desktop_file" | cut -d'=' -f2)
            
            # Skip if no valid exec line
            if [ -z "$exec_line" ]; then
                echo "  ⚠ Skipping $(basename "$desktop_file"): No Exec line found"
                ((failed++))
                continue
            fi
            
            # Backup desktop file
            cp "$desktop_file" "${desktop_file}.backup" 2>/dev/null
            
            # Update to use wrapper
            new_exec="\"$wrapper_script\" $exec_line"
            if sed -i "s|^Exec=.*|Exec=$new_exec|" "$desktop_file" 2>/dev/null; then
                # Add upgrade marker
                if ! grep -q "Upgraded to v2" "$desktop_file"; then
                    # Remove existing comment line and add new one
                    sed -i '/^Comment=/d' "$desktop_file"
                    echo "Comment=Generated by AppImage Integrator; Upgraded to v2" >> "$desktop_file"
                fi
                
                ((updated++))
                name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
                echo "  ✓ Updated $name"
                
                # Remove backup on success
                rm -f "${desktop_file}.backup"
            else
                echo "  ✗ Failed to update $(basename "$desktop_file")"
                # Restore backup
                mv "${desktop_file}.backup" "$desktop_file" 2>/dev/null
                ((failed++))
            fi
        fi
    done
    
    # Update version file
    mkdir -p "$HOME/.config/appimage_desktop_integrator"
    echo "$CURRENT_VERSION" > "$HOME/.config/appimage_desktop_integrator/VERSION"
    
    echo ""
    if [ $failed -gt 0 ]; then
        echo "Upgrade completed with warnings: Updated $updated AppImages, $failed failed."
        echo "Failed entries may need manual intervention."
    else
        echo "Upgrade complete! Updated $updated AppImages."
    fi
    echo ""
    echo "New features available:"
    echo "  - 'ai logs <name>' - View stored logs"
    echo "  - 'ai run <name>' - Run with live output"
    echo "  - Case-insensitive search in all commands"
}

# Check for version and upgrade if needed
check_version_upgrade() {
    local version_file="$HOME/.config/appimage_desktop_integrator/VERSION"
    local installed_version="1.0.0"
    
    # Read version file, default to 1.0.0 if not found or empty
    if [ -f "$version_file" ] && [ -s "$version_file" ]; then
        installed_version=$(cat "$version_file" 2>/dev/null || echo "1.0.0")
    fi
    
    # Validate version format (basic check)
    if ! [[ "$installed_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Warning: Invalid version format in VERSION file, assuming 1.0.0"
        installed_version="1.0.0"
    fi
    
    # Compare versions
    if [ "$installed_version" != "$CURRENT_VERSION" ]; then
        # Extract version components
        local installed_major=$(echo "$installed_version" | cut -d'.' -f1)
        local current_major=$(echo "$CURRENT_VERSION" | cut -d'.' -f1)
        
        # Ensure numeric comparison
        installed_major=${installed_major:-0}
        current_major=${current_major:-0}
        
        if [ "$current_major" -gt "$installed_major" ]; then
            # Check if wrapper already exists (partial upgrade)
            if [ -f "$HOME/.config/appimage_desktop_integrator/bin/appimage-run-wrapper.sh" ]; then
                echo "Note: Logging wrapper already exists, checking desktop entries..."
            fi
            echo "Major version upgrade available!"
            upgrade_to_v2
        else
            # Just update version file for minor updates
            mkdir -p "$HOME/.config/appimage_desktop_integrator"
            echo "$CURRENT_VERSION" > "$version_file"
        fi
    fi
}

# Simpler command structure
show_simple_help() {
    echo "AppImage Integrator (ai) - Simple AppImage Management"
    echo ""
    echo "Quick Commands:"
    echo "  ai                    Show this help"
    echo "  ai status             Show current configuration and status"
    echo "  ai find               Find AppImages on your system"
    echo "  ai install [file]     Install AppImage(s) - prompts if no file given"
    echo "  ai list               List integrated AppImages"  
    echo "  ai remove <n>      Remove an integrated AppImage"
    echo "  ai update <n>      Update an AppImage"
    echo "  ai logs <name>        View logs for an AppImage"
    echo "  ai run <name>         Run an AppImage with live output"
    echo "  ai debug <name>       Run an AppImage with debug/verbose output"
    echo "  ai desktop            Show .desktop files created"
    echo "  ai help               Show detailed help with all options"
    echo ""
    echo "Examples:"
    echo "  ai find               # Find all AppImages on your system"
    echo "  ai install            # Interactive install from found AppImages"
    echo "  ai install ~/Downloads/app.AppImage"
    echo "  ai remove Firefox     # Remove Firefox integration"
    echo ""
}

# Clean AppImage name
clean_appimage_name() {
    local name="$1"
    local original_name="${name%%[^a-zA-Z]*}"
    # Simplified cleaning - cut everything after the first non alphabetic character
    read -p "Use the name [$original_name]? (y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        read -p "Enter a custom name for the AppImage: " name
        # Ensure name is not empty
        if [ -z "$name" ]; then
            echo "Name cannot be empty. Using default: $original_name" >&2
            name="$original_name"
        fi
    else
        name="$original_name"
    fi
    echo "$name"
}

# Check if Electron app
is_electron_app() {
    local appimage="$1"
    local mount_point="$2"
    
    if [[ -f "$mount_point/resources/electron.asar" ]] || \
       [[ -f "$mount_point/chrome-sandbox" ]] || \
       [[ "$appimage" =~ (via|vscode|discord|slack|teams|obsidian|element) ]]; then
        return 0
    fi
    return 1
}

# Process AppImage (main integration function)
process_appimage() {
    local APPIMAGE_PATH="$1"
    local USE_LOGGING="${2:-true}"  # Default to using logging
    
    if ! [ -x "$APPIMAGE_PATH" ]; then
        chmod +x "$APPIMAGE_PATH"
    fi
    
    # Mount and extract info
    echo "Processing $(basename "$APPIMAGE_PATH")..."
    
    # Try to detect sandbox issues
    { DISPLAY= timeout 2 "$APPIMAGE_PATH" --help > /tmp/appimage_test.txt 2>&1 || true; } 2>/dev/null
    
    # Mount the AppImage
    "$APPIMAGE_PATH" --appimage-mount > /tmp/mount_output.txt 2>&1 &
    MOUNT_PID=$!
    sleep 1
    
    if ! read mount_path < /tmp/mount_output.txt; then
        echo "Failed to mount AppImage"
        return 1
    fi
    
    MOUNT_POINT="$mount_path"
    
    # Create logging wrapper if needed
    if [ "$USE_LOGGING" = "true" ]; then
        wrapper_script=$(create_logging_wrapper)
    fi
    
    # Check for Electron/sandbox
    if is_electron_app "$APPIMAGE_PATH" "$MOUNT_POINT" || grep -q "SUID sandbox helper binary" /tmp/appimage_test.txt; then
        if [ "$USE_LOGGING" = "true" ]; then
            EXEC_COMMAND="\"$wrapper_script\" \"$APPIMAGE_PATH\" --no-sandbox"
        else
            EXEC_COMMAND="\"$APPIMAGE_PATH\" --no-sandbox"
        fi
    else
        if [ "$USE_LOGGING" = "true" ]; then
            EXEC_COMMAND="\"$wrapper_script\" \"$APPIMAGE_PATH\""
        else
            EXEC_COMMAND="\"$APPIMAGE_PATH\""
        fi
    fi
    
    # Extract metadata
    VERSION=$(grep 'Version=' "$MOUNT_POINT"/*.desktop 2>/dev/null | cut -d '=' -f2 | head -1)
    ICON=$(find "$MOUNT_POINT" -name '*.png' -o -name '*.svg' | grep -E '(256|128|64|48|icon)' | head -1)
    [ -z "$ICON" ] && ICON=$(find "$MOUNT_POINT" -name '*.png' -o -name '*.svg' | head -1)
    
    APP_NAME=$(clean_appimage_name "$(basename "$APPIMAGE_PATH" .AppImage)")
    CATEGORIES=$(grep 'Categories=' "$MOUNT_POINT"/*.desktop 2>/dev/null | cut -d '=' -f2 | head -1)
    [ -z "$CATEGORIES" ] && CATEGORIES="Utility;Application;"
    
    # Copy icon
    mkdir -p "$icons_dir"
    if [ -n "$ICON" ]; then
        cp "$ICON" "$icons_dir/"
        ICON_PATH="$icons_dir/$(basename "$ICON")"
    else
        ICON_PATH=""
    fi
    
    # Create desktop entry
    DESKTOP_FILE="$(basename "$APPIMAGE_PATH" .AppImage).desktop"
    DESKTOP_PATH="$update_dir/$DESKTOP_FILE"
    
    cat > "$DESKTOP_PATH" <<EOL
[Desktop Entry]
Name=$APP_NAME
Exec=$EXEC_COMMAND
Icon=$ICON_PATH
Type=Application
Version=$VERSION
Categories=$CATEGORIES
Comment=Generated by AppImage Integrator
EOL
    
    # Cleanup
    kill $MOUNT_PID 2>/dev/null
    rm -f /tmp/mount_output.txt /tmp/appimage_test.txt
    
    echo "✓ Integrated $APP_NAME successfully!"
    update-desktop-database "$update_dir" 2>/dev/null
}

# Main command handling
case "${1:-help}" in
    status|info)
        show_status
        ;;
    find|search)
        init_minimal_config
        check_version_upgrade
        find_appimages
        ;;
    install|add)
        init_minimal_config
        check_version_upgrade
        shift
        if [ $# -eq 0 ]; then
            find_appimages
        else
            for appimage in "$@"; do
                if [ -f "$appimage" ]; then
                    install_single_appimage "$appimage"
                else
                    echo "File not found: $appimage"
                fi
            done
        fi
        ;;
    list|ls)
        init_minimal_config
        check_version_upgrade
        list_installed_appimages
        ;;
    remove|uninstall|rm)
        init_minimal_config
        check_version_upgrade
        if [ -z "$2" ]; then
            echo "Usage: ai remove <AppName>"
            echo ""
            echo "Available AppImages:"
            for desktop_file in "$update_dir"/*.desktop; do
                if [ -f "$desktop_file" ] && grep -q "\.AppImage" "$desktop_file" 2>/dev/null; then
                    name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
                    echo "  - $name"
                fi
            done
        else
            # Remove AppImage integration
            found=false
            for desktop_file in "$update_dir"/*.desktop; do
                if [ -f "$desktop_file" ] && grep -q "\.AppImage" "$desktop_file" 2>/dev/null; then
                    name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
                    if [[ "$name" == *"$2"* ]]; then
                        found=true
                        echo "Found: $name"
                        read -p "Remove this AppImage integration? (y/n): " confirm
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            # Get icon path and remove it
                            icon_path=$(grep "^Icon=" "$desktop_file" | cut -d'=' -f2)
                            if [ -f "$icon_path" ] && [[ "$icon_path" == *"appimage-integrator"* || "$icon_path" == *"/icons/"* ]]; then
                                rm -f "$icon_path"
                            fi
                            
                            # Remove desktop entry
                            rm -f "$desktop_file"
                            echo "✓ Removed $name integration"
                            
                            # Update desktop database
                            update-desktop-database "$update_dir" 2>/dev/null
                        fi
                        break
                    fi
                fi
            done
            
            if [ "$found" = false ]; then
                echo "No AppImage found matching: $2"
            fi
        fi
        ;;
    update)
        echo "Update functionality..."
        ;;
    logs|log)
        init_minimal_config
        check_version_upgrade
        view_logs "$2"
        ;;
    run)
        init_minimal_config
        check_version_upgrade
        run_appimage "$2"
        ;;
    debug)
        init_minimal_config
        check_version_upgrade
        debug_appimage "$2"
        ;;
    desktop|desktops)
        init_minimal_config
        show_desktop_files
        ;;
    help|-h|--help|"")
        show_simple_help
        ;;
    *)
        # If it's a .AppImage file, install it
        if [[ "$1" == *.AppImage ]] && [ -f "$1" ]; then
            init_minimal_config
            install_single_appimage "$1"
        else
            echo "Unknown command: $1"
            echo ""
            show_simple_help
        fi
        ;;
esac