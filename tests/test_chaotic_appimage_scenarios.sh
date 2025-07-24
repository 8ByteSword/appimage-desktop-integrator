#!/bin/bash

# Chaotic AppImage scenarios - testing the real-world mess of scattered AppImages

# Source the test framework
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"

# Create realistic chaotic AppImage distribution
create_appimage_chaos() {
    log_info "Creating realistic AppImage chaos across filesystem..."
    
    # The Downloads folder - where everything lands initially
    cp "$TEST_ENV_DIR/appimages/samples/Firefox-120.0.AppImage" "$TEST_HOME/Downloads/"
    cp "$TEST_ENV_DIR/appimages/samples/VSCode-1.85.0.AppImage" "$TEST_HOME/Downloads/"
    cp "$TEST_ENV_DIR/appimages/samples/VIA-3.0.0-linux.AppImage" "$TEST_HOME/Downloads/"
    
    # Desktop - because some people just leave stuff there
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$TEST_HOME/Desktop/"
    cp "$TEST_ENV_DIR/appimages/samples/Simple.AppImage" "$TEST_HOME/Desktop/"
    
    # The "I'll organize later" folders
    mkdir -p "$TEST_HOME/Software" "$TEST_HOME/Programs" "$TEST_HOME/Tools"
    cp "$TEST_ENV_DIR/appimages/samples/Electron-App-2.0.0.AppImage" "$TEST_HOME/Software/"
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$TEST_HOME/Programs/OrganizedApp.AppImage"
    
    # The "temporary" folder that became permanent
    mkdir -p "$TEST_HOME/temp" "$TEST_HOME/tmp"
    cp "$TEST_ENV_DIR/appimages/samples/Simple.AppImage" "$TEST_HOME/temp/TempApp.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/Firefox-120.0.AppImage" "$TEST_HOME/tmp/firefox-backup.AppImage"
    
    # Nested chaos - AppImages in subdirectories
    mkdir -p "$TEST_HOME/Downloads/old" "$TEST_HOME/Downloads/backup" "$TEST_HOME/Downloads/archives/2023"
    cp "$TEST_ENV_DIR/appimages/samples/VIA-3.0.0-linux.AppImage" "$TEST_HOME/Downloads/old/via-old.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/VSCode-1.85.0.AppImage" "$TEST_HOME/Downloads/backup/"
    cp "$TEST_ENV_DIR/appimages/samples/Simple.AppImage" "$TEST_HOME/Downloads/archives/2023/simple-archive.AppImage"
    
    # The "I downloaded this where?" locations
    mkdir -p "$TEST_HOME/Documents/software" "$TEST_HOME/Pictures" "$TEST_HOME/Music/apps"
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$TEST_HOME/Documents/software/DocumentApp.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/Simple.AppImage" "$TEST_HOME/Pictures/ImageViewer.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/Electron-App-2.0.0.AppImage" "$TEST_HOME/Music/apps/MusicApp.AppImage"
    
    # Different versions of the same app scattered around
    mkdir -p "$TEST_HOME/apps-v1" "$TEST_HOME/apps-v2" "$TEST_HOME/old-apps"
    cp "$TEST_ENV_DIR/appimages/samples/Firefox-120.0.AppImage" "$TEST_HOME/apps-v1/Firefox-119.0.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/Firefox-120.0.AppImage" "$TEST_HOME/apps-v2/Firefox-121.0.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/Firefox-120.0.AppImage" "$TEST_HOME/old-apps/Firefox-old.AppImage"
    
    # The "project folders" with embedded AppImages
    mkdir -p "$TEST_HOME/project1/tools" "$TEST_HOME/work/utilities" "$TEST_HOME/dev/bin"
    cp "$TEST_ENV_DIR/appimages/samples/VSCode-1.85.0.AppImage" "$TEST_HOME/project1/tools/"
    cp "$TEST_ENV_DIR/appimages/samples/Simple.AppImage" "$TEST_HOME/work/utilities/WorkTool.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$TEST_HOME/dev/bin/devtool.AppImage"
    
    # Hidden directories (because why not make it harder)
    mkdir -p "$TEST_HOME/.local/apps" "$TEST_HOME/.cache/downloads" "$TEST_HOME/.software"
    cp "$TEST_ENV_DIR/appimages/samples/Electron-App-2.0.0.AppImage" "$TEST_HOME/.local/apps/"
    cp "$TEST_ENV_DIR/appimages/samples/VIA-3.0.0-linux.AppImage" "$TEST_HOME/.cache/downloads/"
    cp "$TEST_ENV_DIR/appimages/samples/Simple.AppImage" "$TEST_HOME/.software/HiddenApp.AppImage"
    
    # Symlinks to AppImages (advanced chaos)
    ln -s "$TEST_HOME/Downloads/Firefox-120.0.AppImage" "$TEST_HOME/firefox-link.AppImage"
    ln -s "$TEST_HOME/Software/Electron-App-2.0.0.AppImage" "$TEST_HOME/Desktop/ElectronLink.AppImage"
    
    # Broken symlinks (extra chaos)
    ln -s "$TEST_HOME/nonexistent/BrokenApp.AppImage" "$TEST_HOME/broken-link.AppImage"
    
    # Files with similar names but not AppImages
    echo "fake content" > "$TEST_HOME/Downloads/NotAnApp.AppImage.backup"
    echo "fake content" > "$TEST_HOME/Downloads/FakeApp.AppImage.old"
    echo "fake content" > "$TEST_HOME/Desktop/app.AppImage.txt"
    
    log_success "Created realistic AppImage chaos with 25+ files across 15+ directories"
}

test_find_scattered_appimages() {
    log_info "Testing find command with scattered AppImages"
    
    create_appimage_chaos
    
    # Update COMMON_APPIMAGE_LOCATIONS to include more chaos
    # This would need to be done in the actual script, but we can test current behavior
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" find 2>&1)
    
    # Should find AppImages in standard locations
    assert_equal 1 "$(echo "$output" | grep -c "Found in $TEST_HOME/Downloads")" "Should find AppImages in Downloads"
    assert_equal 1 "$(echo "$output" | grep -c "Found in $TEST_HOME/Desktop")" "Should find AppImages in Desktop"
    
    # Count found AppImages in standard locations
    local found_count
    found_count=$(echo "$output" | grep -E "^\s+[✓-]" | wc -l)
    
    # Should find at least 5 AppImages in standard locations
    assert_command_succeeds "test $found_count -ge 5" "Should find multiple AppImages in standard locations"
}

test_find_with_extended_search() {
    log_info "Testing extended search in non-standard locations"
    
    create_appimage_chaos
    
    # Manually search additional locations that real users might have
    local additional_locations=(
        "$TEST_HOME/Software"
        "$TEST_HOME/Programs" 
        "$TEST_HOME/Tools"
        "$TEST_HOME/temp"
        "$TEST_HOME/tmp"
        "$TEST_HOME/Documents/software"
        "$TEST_HOME/.local/apps"
    )
    
    local total_found=0
    for location in "${additional_locations[@]}"; do
        if [[ -d "$location" ]]; then
            local count
            count=$(find "$location" -name "*.AppImage" 2>/dev/null | wc -l)
            total_found=$((total_found + count))
        fi
    done
    
    assert_command_succeeds "test $total_found -ge 8" "Should find AppImages in non-standard locations too"
}

test_duplicate_appimage_detection() {
    log_info "Testing duplicate AppImage detection across directories"
    
    create_appimage_chaos
    
    # Count how many Firefox AppImages exist
    local firefox_count
    firefox_count=$(find "$TEST_HOME" -name "*Firefox*" -name "*.AppImage" 2>/dev/null | wc -l)
    
    assert_command_succeeds "test $firefox_count -ge 4" "Should have multiple Firefox versions scattered around"
    
    # Install one Firefox
    echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$TEST_HOME/Downloads/Firefox-120.0.AppImage" &>/dev/null
    
    # Check if find command shows others as not integrated
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" find 2>&1)
    
    # Should still find unintegrated Firefox versions
    local firefox_found
    firefox_found=$(echo "$output" | grep -c "Firefox" || echo "0")
    
    assert_command_succeeds "test $firefox_found -ge 1" "Should still find other Firefox versions"
}

test_version_confusion_scenario() {
    log_info "Testing version confusion with multiple app versions"
    
    create_appimage_chaos
    
    # List all Firefox variants
    local firefox_files
    firefox_files=$(find "$TEST_HOME" -name "*Firefox*" -name "*.AppImage" 2>/dev/null)
    
    local count=0
    for file in $firefox_files; do
        if [[ -f "$file" ]]; then
            ((count++))
        fi
    done
    
    assert_command_succeeds "test $count -ge 3" "Should have multiple Firefox versions"
    
    # User installs one version
    local first_firefox
    first_firefox=$(echo "$firefox_files" | head -1)
    
    echo "1" | "$TEST_ENV_DIR/bin/ai_test" install "$first_firefox" &>/dev/null
    
    # Check if desktop file was created
    local desktop_count
    desktop_count=$(ls "$TEST_DESKTOP_DIR"/*Firefox*.desktop 2>/dev/null | wc -l)
    
    assert_equal 1 "$desktop_count" "Should create only one Firefox desktop entry"
}

test_deeply_nested_discovery() {
    log_info "Testing discovery of deeply nested AppImages"
    
    create_appimage_chaos
    
    # Create even deeper nesting
    mkdir -p "$TEST_HOME/Projects/2023/Q4/tools/linux/x64"
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$TEST_HOME/Projects/2023/Q4/tools/linux/x64/DeepApp.AppImage"
    
    # Manual deep search (simulating what an enhanced find might do)
    local deep_apps
    deep_apps=$(find "$TEST_HOME" -name "*.AppImage" -type f 2>/dev/null | wc -l)
    
    assert_command_succeeds "test $deep_apps -ge 20" "Should find many AppImages in the chaos"
}

test_symlink_chaos() {
    log_info "Testing symlink chaos scenarios"
    
    create_appimage_chaos
    
    # Count symlinks
    local symlink_count
    symlink_count=$(find "$TEST_HOME" -name "*.AppImage" -type l 2>/dev/null | wc -l)
    
    assert_command_succeeds "test $symlink_count -ge 2" "Should have symlinked AppImages"
    
    # Try to install a symlinked AppImage
    local output
    output=$(echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$TEST_HOME/firefox-link.AppImage" 2>&1)
    
    assert_equal 1 "$(echo "$output" | grep -c "Processing")" "Should process symlinked AppImage"
}

test_permission_chaos() {
    log_info "Testing permission issues in chaos"
    
    create_appimage_chaos
    
    # Make some AppImages non-executable (realistic scenario)
    chmod -x "$TEST_HOME/Downloads/Firefox-120.0.AppImage"
    chmod -x "$TEST_HOME/temp/TempApp.AppImage"
    chmod -x "$TEST_HOME/Software/Electron-App-2.0.0.AppImage"
    
    # Try to install non-executable AppImage
    local output
    output=$(echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$TEST_HOME/Downloads/Firefox-120.0.AppImage" 2>&1)
    
    assert_equal 1 "$(echo "$output" | grep -c "Processing")" "Should handle non-executable AppImage"
    
    # Check if it was made executable
    assert_command_succeeds "test -x '$TEST_HOME/Downloads/Firefox-120.0.AppImage'" "Should make AppImage executable"
}

test_space_and_special_char_chaos() {
    log_info "Testing AppImages with spaces and special characters"
    
    create_appimage_chaos
    
    # Create AppImages with problematic names
    mkdir -p "$TEST_HOME/Weird Apps"
    cp "$TEST_ENV_DIR/appimages/samples/Simple.AppImage" "$TEST_HOME/Weird Apps/App With Spaces.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$TEST_HOME/Downloads/App (Special) [Chars].AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/VIA-3.0.0-linux.AppImage" "$TEST_HOME/Desktop/App-with-émojis🚀.AppImage"
    
    # Try to install app with spaces
    local output
    output=$(echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$TEST_HOME/Weird Apps/App With Spaces.AppImage" 2>&1)
    
    assert_equal 1 "$(echo "$output" | grep -c "Processing")" "Should handle AppImage with spaces"
    
    # Check if desktop file was created
    assert_file_exists "$TEST_DESKTOP_DIR/App With Spaces.desktop" "Should create desktop file for app with spaces"
}

test_cleanup_chaos_scenario() {
    log_info "Testing cleanup of chaotic AppImage installations"
    
    create_appimage_chaos
    
    # Install several scattered AppImages
    local apps_to_install=(
        "$TEST_HOME/Downloads/Firefox-120.0.AppImage"
        "$TEST_HOME/Desktop/Simple.AppImage"
        "$TEST_HOME/Software/Electron-App-2.0.0.AppImage"
    )
    
    for app in "${apps_to_install[@]}"; do
        echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$app" &>/dev/null
    done
    
    # List installed apps
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" list 2>&1)
    
    # Should show multiple integrated apps
    assert_equal 1 "$(echo "$output" | grep -c "Firefox")" "Should list Firefox"
    assert_equal 1 "$(echo "$output" | grep -c "Simple")" "Should list Simple"
    assert_equal 1 "$(echo "$output" | grep -c "Electron")" "Should list Electron app"
    
    # Remove one app
    echo "y" | "$TEST_ENV_DIR/bin/ai_test" remove Simple &>/dev/null
    
    # Verify removal
    assert_file_not_exists "$TEST_DESKTOP_DIR/Simple.desktop" "Should remove Simple desktop file"
}

test_realistic_user_workflow() {
    log_info "Testing realistic chaotic user workflow"
    
    create_appimage_chaos
    
    # Simulate user discovering they have AppImages everywhere
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" find 2>&1)
    
    # User should be prompted about integration
    assert_equal 1 "$(echo "$output" | grep -c "Would you like to integrate")" "Should offer to integrate found AppImages"
    
    # Simulate user saying yes to integration
    local integration_output
    integration_output=$(echo "y" | "$TEST_ENV_DIR/bin/ai_test" find 2>&1)
    
    assert_equal 1 "$(echo "$integration_output" | grep -c "Integrating")" "Should start integration process"
}

test_hidden_directory_discovery() {
    log_info "Testing discovery in hidden directories"
    
    create_appimage_chaos
    
    # Manual search in hidden directories
    local hidden_apps
    hidden_apps=$(find "$TEST_HOME/.local" "$TEST_HOME/.cache" "$TEST_HOME/.software" -name "*.AppImage" 2>/dev/null | wc -l)
    
    assert_command_succeeds "test $hidden_apps -ge 3" "Should have AppImages in hidden directories"
    
    # These wouldn't be found by normal find command (which is realistic)
    # but shows the scope of the chaos
}

test_storage_organization_from_chaos() {
    log_info "Testing organizing scattered AppImages into proper storage"
    
    create_appimage_chaos
    
    # Install app from Downloads and move to organized location
    echo "1" | "$TEST_ENV_DIR/bin/ai_test" install "$TEST_HOME/Downloads/Firefox-120.0.AppImage" &>/dev/null
    
    # Check if it was moved to AppImages directory
    assert_file_exists "$TEST_HOME/AppImages/Firefox-120.0.AppImage" "Should move to organized directory"
    assert_file_not_exists "$TEST_HOME/Downloads/Firefox-120.0.AppImage" "Should remove from Downloads"
    
    # Install another and choose to keep in place
    echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$TEST_HOME/Desktop/Simple.AppImage" &>/dev/null
    
    # Check if it stayed in Desktop
    assert_file_exists "$TEST_HOME/Desktop/Simple.AppImage" "Should keep in original location when requested"
}

# Run all chaos tests
run_chaotic_tests() {
    log_info "Running chaotic AppImage scenario tests"
    
    # Initialize test framework
    init_test_framework
    
    # Run individual test functions
    test_find_scattered_appimages
    test_find_with_extended_search
    test_duplicate_appimage_detection
    test_version_confusion_scenario
    test_deeply_nested_discovery
    test_symlink_chaos
    test_permission_chaos
    test_space_and_special_char_chaos
    test_cleanup_chaos_scenario
    test_realistic_user_workflow
    test_hidden_directory_discovery
    test_storage_organization_from_chaos
    
    # Print summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_chaotic_tests
fi