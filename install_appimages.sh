#!/bin/bash

# Version info - read from VERSION file
get_current_version() {
    # Version will be embedded during installation by setup script
    # This placeholder gets replaced with actual version
    echo "__VERSION_PLACEHOLDER__"
}

# CURRENT_VERSION will be set by get_current_version() when needed

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
    # Global variables for config
    icons_dir=""
    update_dir=""
    appimages_dir=""
    appimages_dirs=()
    temp_dirs=()  # Declare outside the loop to avoid scope issues
    
    config_path="$HOME/.config/appimage_desktop_integrator"
    
    # Only enable debug output if APPIMAGE_INTEGRATOR_DEBUG is set (not just TEST_ENV_DIR)
    local debug_enabled=false
    if [ -n "$APPIMAGE_INTEGRATOR_DEBUG" ]; then
        debug_enabled=true
        echo "[DEBUG] init_minimal_config: config_path=$config_path" >&2
        echo "[DEBUG] init_minimal_config: HOME=$HOME" >&2
    fi
    
    if [ -f "$config_path/config.ini" ]; then
        # Use process substitution to avoid subshell issues
        while IFS='=' read -r key value || [ -n "$key" ]; do
            # Skip comments and empty lines
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            # Remove leading/trailing whitespace using parameter expansion instead of xargs
            key="${key#"${key%%[![:space:]]*}"}"  # Remove leading whitespace
            key="${key%"${key##*[![:space:]]}"}"  # Remove trailing whitespace
            value="${value#"${value%%[![:space:]]*}"}"  # Remove leading whitespace
            value="${value%"${value##*[![:space:]]}"}"  # Remove trailing whitespace
            
            # Debug output only when explicitly enabled
            if [ "$debug_enabled" = true ]; then
                echo "[DEBUG] Parsing key='$key', value='$value'" >&2
            fi
            
            # Parse known config values safely
            case "$key" in
                icons_dir)
                    # Expand ~ to $HOME safely
                    icons_dir="${value/#\~/$HOME}"
                    [ "$debug_enabled" = true ] && echo "[DEBUG] Set icons_dir=$icons_dir" >&2
                    ;;
                update_dir)
                    update_dir="${value/#\~/$HOME}"
                    [ "$debug_enabled" = true ] && echo "[DEBUG] Set update_dir=$update_dir" >&2
                    ;;
                appimages_dir)
                    # Legacy single directory support
                    appimages_dir="${value/#\~/$HOME}"
                    [ "$debug_enabled" = true ] && echo "[DEBUG] Set appimages_dir=$appimages_dir" >&2
                    ;;
                appimages_dirs)
                    # Handle array format safely - extract values between quotes
                    temp_dirs=()  # Reset temp array
                    if [[ "$value" =~ ^\( ]]; then
                        [ "$debug_enabled" = true ] && echo "[DEBUG] Processing appimages_dirs array: $value" >&2
                        # Extract quoted values from array format
                        local remaining_value="$value"
                        while [[ "$remaining_value" =~ \"([^\"]+)\" ]]; do
                            dir="${BASH_REMATCH[1]}"
                            dir="${dir/#\~/$HOME}"
                            temp_dirs+=("$dir")
                            [ "$debug_enabled" = true ] && echo "[DEBUG] Added directory: $dir" >&2
                            remaining_value="${remaining_value/${BASH_REMATCH[0]}/}"
                        done
                        appimages_dirs=("${temp_dirs[@]}")
                        [ "$debug_enabled" = true ] && echo "[DEBUG] Final appimages_dirs: ${appimages_dirs[*]}" >&2
                    fi
                    ;;
                *)
                    # Ignore unknown config keys for security
                    [ "$debug_enabled" = true ] && echo "[DEBUG] Ignoring unknown key: $key" >&2
                    ;;
            esac
        done < <(cat "$config_path/config.ini")

        # Handle old config format (single appimages_dir)
        if [ -n "$appimages_dir" ] && [ ${#appimages_dirs[@]} -eq 0 ]; then
            appimages_dirs=("$appimages_dir")
            [ "$debug_enabled" = true ] && echo "[DEBUG] Used legacy appimages_dir: $appimages_dir" >&2
        fi
        
        # Ensure appimages_dirs is an array
        if [ ${#appimages_dirs[@]} -eq 0 ]; then
            appimages_dirs=("$HOME/AppImages" "$HOME/Applications")
            [ "$debug_enabled" = true ] && echo "[DEBUG] Used default appimages_dirs: ${appimages_dirs[*]}" >&2
        fi
    else
        icons_dir="$HOME/.local/share/icons/appimage-integrator"
        appimages_dirs=("$HOME/AppImages" "$HOME/Applications")
        update_dir="$HOME/.local/share/applications"
        [ "$debug_enabled" = true ] && echo "[DEBUG] No config file, using defaults" >&2
    fi
    
    # Clean up temp variable
    unset temp_dirs
    
    # Debug final state only when explicitly enabled
    if [ "$debug_enabled" = true ]; then
        echo "[DEBUG] Final config:" >&2
        echo "[DEBUG]   icons_dir=$icons_dir" >&2
        echo "[DEBUG]   update_dir=$update_dir" >&2
        echo "[DEBUG]   appimages_dirs=(${appimages_dirs[*]})" >&2
        echo "[DEBUG]   appimages_dirs count=${#appimages_dirs[@]}" >&2
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
    check_version_upgrade
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
            count=$(find "$dir" -iname "*.appimage" 2>/dev/null | wc -l)
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
            if [[ "${exec_line,,}" == *".appimage"* ]]; then
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
            appimages=($(find "$location" -maxdepth 2 -iname "*.appimage" 2>/dev/null))
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
    local base_name="${appimage_name%.*}"
    
    for desktop_file in "$update_dir"/*.desktop; do
        if [ -f "$desktop_file" ]; then
            # More flexible check - look for the AppImage in Exec line
            if grep -iq "$base_name.*\.appimage" "$desktop_file" 2>/dev/null; then
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
    
    # ATOMIC FIX: Process AppImage FIRST in original location
    # Only move if processing succeeds
    local final_path="$appimage_path"
    local needs_move=false
    
    if [ "$original_path" != "$target_dir" ]; then
        needs_move=true
        echo "Will move $appimage_name to $target_dir after successful processing..."
    fi
    
    # Process the AppImage in original location
    if process_appimage "$appimage_path"; then
        # Processing succeeded - now move if needed
        if [ "$needs_move" = true ]; then
            echo "Moving $appimage_name to $target_dir..."
            if mv "$appimage_path" "$target_dir/"; then
                final_path="$target_dir/$appimage_name"
                # Update desktop file with new path
                local desktop_file="$(basename "$appimage_path" | sed 's/\.[Aa]pp[Ii]mage$//')".desktop
                local desktop_path="$update_dir/$desktop_file"
                if [ -f "$desktop_path" ]; then
                    sed -i "s|$appimage_path|$final_path|g" "$desktop_path"
                fi
            else
                echo "Warning: Failed to move file, but integration completed at original location" >&2
            fi
        fi
    else
        # Processing failed - file stays in original location
        if [ "$needs_move" = true ]; then
            echo "Processing failed - AppImage remains at: $appimage_path" >&2
        fi
        return 1
    fi
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
            if [[ "${exec_line,,}" == *".appimage"* ]]; then
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
            if grep -iq "\.appimage" "$desktop_file" 2>/dev/null; then
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
            if [ -f "$desktop_file" ] && grep -q "\.[Aa]pp[Ii]mage" "$desktop_file" 2>/dev/null; then
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
        if [ -f "$desktop_file" ] && grep -q "\.[Aa]pp[Ii]mage" "$desktop_file" 2>/dev/null; then
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
            if [ -f "$desktop_file" ] && grep -q "\.[Aa]pp[Ii]mage" "$desktop_file" 2>/dev/null; then
                name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
                echo "  - $name"
            fi
        done
        return
    fi
    
    # Find the AppImage (case-insensitive)
    for desktop_file in "$update_dir"/*.desktop; do
        if [ -f "$desktop_file" ] && grep -q "\.[Aa]pp[Ii]mage" "$desktop_file" 2>/dev/null; then
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
            if [ -f "$desktop_file" ] && grep -q "\.[Aa]pp[Ii]mage" "$desktop_file" 2>/dev/null; then
                name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
                echo "  - $name"
            fi
        done
        return
    fi
    
    # Find the AppImage (case-insensitive)
    for desktop_file in "$update_dir"/*.desktop; do
        if [ -f "$desktop_file" ] && grep -q "\.[Aa]pp[Ii]mage" "$desktop_file" 2>/dev/null; then
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
# Log rotation function
rotate_log_if_needed() {
    local log_file="$1"
    local max_size=$((10 * 1024 * 1024)) # 10MB
    
    if [[ -f "$log_file" ]] && [[ $(stat -c%s "$log_file" 2>/dev/null || echo 0) -gt $max_size ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Rotating log file (exceeded ${max_size} bytes)" >> "$log_file"
        
        # Keep last 1000 lines
        if command -v tail >/dev/null 2>&1; then
            mv "$log_file" "${log_file}.old"
            tail -n 1000 "${log_file}.old" > "$log_file" 2>/dev/null || touch "$log_file"
            rm -f "${log_file}.old"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotated - kept last 1000 lines" >> "$log_file"
        fi
    fi
}

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
APPIMAGE_NAME=$(basename "$APPIMAGE_PATH" | sed 's/\.[Aa]pp[Ii]mage$//')

# Set up logging
LOGS_DIR="$HOME/.config/appimage_desktop_integrator/logs"
mkdir -p "$LOGS_DIR"
LOG_FILE="$LOGS_DIR/${APPIMAGE_NAME}.log"

# Log rotation function
rotate_log_if_needed() {
    local log_file="$1"
    local max_size=$((10 * 1024 * 1024)) # 10MB
    
    if [[ -f "$log_file" ]] && [[ $(stat -c%s "$log_file" 2>/dev/null || echo 0) -gt $max_size ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Rotating log file (exceeded ${max_size} bytes)" >> "$log_file"
        
        # Keep last 1000 lines
        if command -v tail >/dev/null 2>&1; then
            mv "$log_file" "${log_file}.old"
            tail -n 1000 "${log_file}.old" > "$log_file" 2>/dev/null || touch "$log_file"
            rm -f "${log_file}.old"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotated - kept last 1000 lines" >> "$log_file"
        fi
    fi
}

# Check for no-logging mode
if [[ "${APPIMAGE_NO_LOG}" == "1" ]]; then
    exec "$APPIMAGE_PATH" "$@"
fi

# Rotate log if needed before writing
rotate_log_if_needed "$LOG_FILE"

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
# Upgrade function removed - users should reinstall for updates

# Check for version and upgrade if needed
check_version_upgrade() {
    # Ensure CURRENT_VERSION is set
    CURRENT_VERSION=$(get_current_version)
    # No upgrade checking needed - embedded version is authoritative
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
    
    # Remove common file extensions first
    name="${name%%.AppImage}"
    name="${name%%.appimage}"
    name="${name%%.APPIMAGE}"
    
    # Remove version patterns and platform indicators
    # Strip version numbers like v1.2.3, 1.2.3, 2024-01-01
    name=$(echo "$name" | sed -E 's/[-_]v?[0-9]+(\.[0-9]+)*(\.[0-9]+)?.*$//')
    # Strip platform indicators
    name=$(echo "$name" | sed -E 's/[-_](linux|x86_64|amd64|i386|arm64|armhf).*$//')
    # Strip date patterns
    name=$(echo "$name" | sed -E 's/[-_][0-9]{4}[-_][0-9]{2}[-_][0-9]{2}.*$//')
    # Strip git hash patterns
    name=$(echo "$name" | sed -E 's/[-_]git[-_][a-f0-9]{7,}.*$//')
    
    # Extract clean name - letters, numbers, and common separators
    local cleaned=$(echo "$name" | sed -E 's/^[^a-zA-Z0-9]*//; s/[^a-zA-Z0-9]*$//; s/[-_]+/ /g')
    
    # Capitalize first letter of each word
    local original_name=""
    for word in $cleaned; do
        if [ -n "$original_name" ]; then
            original_name="$original_name "
        fi
        original_name="$original_name$(echo "${word:0:1}" | tr '[:lower:]' '[:upper:]')${word:1}"
    done
    
    # Fallback to first alphabetic sequence if cleaning failed
    if [ -z "$original_name" ]; then
        original_name="${name%%[^a-zA-Z]*}"
    fi
    
    # Ensure we have something
    if [ -z "$original_name" ]; then
        original_name="AppImage"
    fi
    
    # Ask user for confirmation with improved suggestion
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
# Cleanup function for AppImage mounts and temp files
cleanup_appimage_mount() {
    local mount_pid="$1"
    local mount_point="$2"
    
    # Kill the mount process if still running
    if kill "$mount_pid" 2>/dev/null; then
        sleep 0.5
        # Ensure it's properly unmounted
        if [ -n "$mount_point" ] && mountpoint -q "$mount_point" 2>/dev/null; then
            fusermount -u "$mount_point" 2>/dev/null || fusermount3 -u "$mount_point" 2>/dev/null || true
        fi
    fi
    
    # Clean up temporary files
    rm -f /tmp/mount_output.txt /tmp/appimage_test.txt
}

# Error handling function
handle_error() {
    local exit_code=$1
    local message="$2"
    local line_no="$3"
    
    echo "Error on line $line_no: $message (exit code: $exit_code)" >&2
    
    # Log error if we have access to logging
    if [ -n "$HOME" ]; then
        local error_log="$HOME/.config/appimage_desktop_integrator/errors.log"
        mkdir -p "$(dirname "$error_log")"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: $message (line $line_no, exit $exit_code)" >> "$error_log"
    fi
    
    # Cleanup any partial operations
    cleanup_on_exit
}

# Global cleanup function
cleanup_on_exit() {
    local exit_code=$?
    
    # Clean up any AppImage mounts
    if [ -n "$MOUNT_PID" ]; then
        cleanup_appimage_mount "$MOUNT_PID" "$MOUNT_POINT"
    fi
    
    # Remove any temporary directories
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    
    # Clean up any temporary files with our pattern
    rm -f /tmp/appimage_*.txt /tmp/mount_output.txt 2>/dev/null
    
    # Only exit if this is being called as an exit handler
    if [ "${BASH_SUBSHELL}" = "0" ]; then
        exit $exit_code
    fi
}

# Set up cleanup trap
trap cleanup_on_exit EXIT INT TERM

# Atomic desktop file update function
update_desktop_file_atomic() {
    local desktop_path="$1"
    local app_name="$2"
    local exec_command="$3"
    local icon_path="$4"
    local version="$5"
    local categories="$6"
    
    local temp_file="${desktop_path}.tmp"
    
    # Create new desktop file in temporary location
    cat > "$temp_file" <<EOF
[Desktop Entry]
Name=$app_name
Exec=$exec_command
Icon=$icon_path
Type=Application
Version=$version
Categories=$categories
Comment=Generated by AppImage Integrator
EOF
    
    # Verify the temp file was created successfully
    if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
        # Atomic replace - this is atomic on most filesystems
        if mv "$temp_file" "$desktop_path" 2>/dev/null; then
            # Update desktop database
            update-desktop-database "$update_dir" 2>/dev/null
            return 0
        else
            # Cleanup on failure
            rm -f "$temp_file"
            return 1
        fi
    else
        # Cleanup on failure
        rm -f "$temp_file"
        return 1
    fi
}

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
    
    APP_NAME=$(clean_appimage_name "$(basename "$APPIMAGE_PATH" | sed 's/\.[Aa]pp[Ii]mage$//')")
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
    DESKTOP_FILE="$(basename "$APPIMAGE_PATH" | sed 's/\.[Aa]pp[Ii]mage$//')".desktop
    DESKTOP_PATH="$update_dir/$DESKTOP_FILE"
    
    # Use atomic desktop file update
    if ! update_desktop_file_atomic "$DESKTOP_PATH" "$APP_NAME" "$EXEC_COMMAND" "$ICON_PATH" "$VERSION" "$CATEGORIES"; then
        echo "Error: Failed to create desktop file $DESKTOP_PATH" >&2
        return 1
    fi
    
    # Cleanup mount and temporary files
    cleanup_appimage_mount "$MOUNT_PID" "$MOUNT_POINT"
    
    echo "✓ Integrated $APP_NAME successfully!"
}

# Intelligent removal function with fuzzy matching
intelligent_remove_appimage() {
    local search_term="$1"
    local matches=()
    local names=()
    local desktop_files=()
    
    # Find all possible matches (case-insensitive)
    for desktop_file in "$update_dir"/*.desktop; do
        if [ -f "$desktop_file" ] && grep -q "\.[Aa]pp[Ii]mage" "$desktop_file" 2>/dev/null; then
            name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
            # Case-insensitive matching with multiple criteria
            if [[ "${name,,}" == *"${search_term,,}"* ]] || \
               [[ "${name,,}" == "${search_term,,}" ]] || \
               [[ "$(basename "$desktop_file" .desktop | tr '[:upper:]' '[:lower:]')" == *"${search_term,,}"* ]]; then
                matches+=("$name")
                names+=("$name")
                desktop_files+=("$desktop_file")
            fi
        fi
    done
    
    # Handle results
    case ${#matches[@]} in
        0)
            echo "No AppImage found matching: $search_term"
            echo ""
            echo "Did you mean one of these?"
            for desktop_file in "$update_dir"/*.desktop; do
                if [ -f "$desktop_file" ] && grep -q "\.[Aa]pp[Ii]mage" "$desktop_file" 2>/dev/null; then
                    name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
                    echo "  - $name"
                fi
            done
            return 1
            ;;
        1)
            # Exact match - proceed with removal
            remove_appimage_integration "${desktop_files[0]}" "${names[0]}"
            ;;
        *)
            # Multiple matches - ask user to choose
            echo "Multiple AppImages match '$search_term':"
            echo ""
            for i in "${!matches[@]}"; do
                echo "  $((i+1))) ${matches[i]}"
            done
            echo "  0) Cancel"
            echo ""
            read -p "Which one would you like to remove? (1-${#matches[@]}, 0 to cancel): " choice
            
            if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le "${#matches[@]}" ]; then
                local idx=$((choice-1))
                remove_appimage_integration "${desktop_files[idx]}" "${names[idx]}"
            elif [ "$choice" = "0" ]; then
                echo "Removal cancelled."
            else
                echo "Invalid choice. Removal cancelled."
            fi
            ;;
    esac
}

# Function to actually remove the AppImage integration
remove_appimage_integration() {
    local desktop_file="$1"
    local name="$2"
    
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
    else
        echo "Removal cancelled."
    fi
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
                if [ -f "$desktop_file" ] && grep -q "\.[Aa]pp[Ii]mage" "$desktop_file" 2>/dev/null; then
                    name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
                    echo "  - $name"
                fi
            done
        else
            # Use intelligent removal function
            intelligent_remove_appimage "$2"
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
    --version|-v)
        CURRENT_VERSION=$(get_current_version)
        echo "AppImage Integrator v$CURRENT_VERSION"
        echo "Enhanced with security improvements, case-insensitive support, and atomic operations"
        ;;
    --dry-run)
        echo "Dry run mode - would execute: $*"
        echo "Note: Dry run functionality not fully implemented yet"
        ;;
    help|-h|--help|"")
        show_simple_help
        ;;
    *)
        # If it's a .AppImage file, install it
        if [[ "${1,,}" == *.appimage ]] && [ -f "$1" ]; then
            init_minimal_config
            install_single_appimage "$1"
        else
            echo "Unknown command: $1"
            echo ""
            show_simple_help
        fi
        ;;
esac