#!/bin/bash

# Edge cases and error handling tests

# Source the test framework
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"

# Test functions
test_invalid_appimage_path() {
    log_info "Testing invalid AppImage path handling"
    
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" install "/nonexistent/path/app.AppImage" 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "Command should handle invalid path gracefully"
    assert_equal 1 "$(echo "$output" | grep -c "File not found")" "Should report file not found"
}

test_non_executable_appimage() {
    log_info "Testing non-executable AppImage handling"
    
    # Create a non-executable AppImage
    local test_appimage="$TEST_HOME/Downloads/NonExecTest.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$test_appimage"
    chmod -x "$test_appimage"
    
    # Try to install it
    local output
    output=$(echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$test_appimage" 2>&1)
    
    # Should succeed after making it executable
    assert_equal 1 "$(echo "$output" | grep -c "Processing")" "Should process non-executable AppImage"
    
    # Check if it was made executable
    assert_command_succeeds "test -x '$test_appimage'" "AppImage should be made executable"
}

test_missing_desktop_directory() {
    log_info "Testing missing desktop directory handling"
    
    # Remove desktop directory
    rm -rf "$TEST_DESKTOP_DIR"
    
    # Try to install an AppImage
    local test_appimage="$TEST_HOME/Downloads/DirTest.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$test_appimage"
    
    echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$test_appimage" &>/dev/null
    
    # Directory should be created and desktop file should exist
    assert_dir_exists "$TEST_DESKTOP_DIR" "Desktop directory should be created"
    assert_file_exists "$TEST_DESKTOP_DIR/DirTest.desktop" "Desktop file should be created"
}

test_corrupted_config_file() {
    log_info "Testing corrupted config file handling"
    
    # Create corrupted config file
    echo "invalid config content" > "$TEST_CONFIG_DIR/config.ini"
    
    # Try to run status command
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" status 2>&1)
    local exit_code=$?
    
    # Should handle gracefully and still show status
    assert_equal 0 "$exit_code" "Should handle corrupted config gracefully"
    assert_equal 1 "$(echo "$output" | grep -c "Current Status")" "Should still show status"
}

test_missing_version_file() {
    log_info "Testing missing version file handling"
    
    # Remove version file
    rm -f "$TEST_CONFIG_DIR/VERSION"
    
    # Run command that checks version
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" status 2>&1)
    
    # Should handle missing version file
    assert_file_exists "$TEST_CONFIG_DIR/VERSION" "Version file should be created"
}

test_empty_version_file() {
    log_info "Testing empty version file handling"
    
    # Create empty version file
    touch "$TEST_CONFIG_DIR/VERSION"
    
    # Run command that checks version
    "$TEST_ENV_DIR/bin/ai_test" status &>/dev/null
    
    # Should handle empty version file
    local version_content
    version_content=$(cat "$TEST_CONFIG_DIR/VERSION")
    
    assert_equal "2.0.0" "$version_content" "Empty version file should be updated"
}

test_invalid_version_format() {
    log_info "Testing invalid version format handling"
    
    # Create version file with invalid format
    echo "invalid.version.format" > "$TEST_CONFIG_DIR/VERSION"
    
    # Run command that checks version
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" status 2>&1)
    
    # Should handle invalid version format
    assert_equal 1 "$(echo "$output" | grep -c "Invalid version format")" "Should warn about invalid version format"
}

test_permission_denied_scenarios() {
    log_info "Testing permission denied scenarios"
    
    # Create a directory without write permissions
    local readonly_dir="$TEST_HOME/ReadOnlyDir"
    mkdir -p "$readonly_dir"
    chmod 444 "$readonly_dir"
    
    # Try to install AppImage there
    local test_appimage="$TEST_HOME/Downloads/PermTest.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$test_appimage"
    
    # Custom install location (choice 4)
    local output
    output=$(printf "4\n%s\n" "$readonly_dir" | "$TEST_ENV_DIR/bin/ai_test" install "$test_appimage" 2>&1)
    
    # Should handle permission error gracefully
    # Note: The actual behavior depends on implementation, but it shouldn't crash
    assert_equal 1 "$(echo "$output" | grep -c "Custom location")" "Should ask for custom location"
    
    # Clean up
    chmod 755 "$readonly_dir"
}

test_case_insensitive_search() {
    log_info "Testing case-insensitive search functionality"
    
    # Install an AppImage
    local test_appimage="$TEST_HOME/Downloads/CaseTest.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$test_appimage"
    
    echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$test_appimage" &>/dev/null
    
    # Test case-insensitive removal
    local output
    output=$(echo "y" | "$TEST_ENV_DIR/bin/ai_test" remove casetest 2>&1)
    
    assert_equal 1 "$(echo "$output" | grep -c "Found: CaseTest")" "Should find AppImage with case-insensitive search"
}

test_special_characters_in_names() {
    log_info "Testing special characters in AppImage names"
    
    # Create AppImage with special characters
    local test_appimage="$TEST_HOME/Downloads/Special-App_v1.0.0.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$test_appimage"
    
    echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$test_appimage" &>/dev/null
    
    # Check if desktop file was created properly
    local desktop_file="$TEST_DESKTOP_DIR/Special-App_v1.0.0.desktop"
    assert_file_exists "$desktop_file" "Desktop file should handle special characters"
    
    # Check if name was cleaned properly
    local name_line
    name_line=$(grep "^Name=" "$desktop_file")
    
    assert_equal 1 "$(echo "$name_line" | grep -c "Special")" "Name should contain 'Special'"
}

test_very_long_paths() {
    log_info "Testing very long path handling"
    
    # Create a deep directory structure
    local deep_dir="$TEST_HOME/very/deep/directory/structure/for/testing/long/paths"
    mkdir -p "$deep_dir"
    
    # Place AppImage in deep directory
    local test_appimage="$deep_dir/DeepTest.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$test_appimage"
    
    # Try to install it
    local output
    output=$(echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$test_appimage" 2>&1)
    
    # Should handle long paths
    assert_equal 1 "$(echo "$output" | grep -c "Processing")" "Should process AppImage with long path"
}

test_multiple_appimages_same_name() {
    log_info "Testing multiple AppImages with same name"
    
    # Create two AppImages with same name in different directories
    local test_app1="$TEST_HOME/Downloads/SameName.AppImage"
    local test_app2="$TEST_HOME/Desktop/SameName.AppImage"
    
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$test_app1"
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$test_app2"
    
    # Install both
    echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$test_app1" &>/dev/null
    echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$test_app2" &>/dev/null
    
    # Check if both were handled (second one should replace first)
    local desktop_count
    desktop_count=$(ls "$TEST_DESKTOP_DIR"/SameName*.desktop 2>/dev/null | wc -l)
    
    assert_equal 1 "$desktop_count" "Should handle duplicate names properly"
}

test_symlink_handling() {
    log_info "Testing symlink handling"
    
    # Create a symlink to an AppImage
    local test_appimage="$TEST_HOME/Downloads/SymlinkTest.AppImage"
    local symlink_path="$TEST_HOME/Downloads/SymlinkTest-Link.AppImage"
    
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$test_appimage"
    ln -s "$test_appimage" "$symlink_path"
    
    # Try to install the symlink
    local output
    output=$(echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$symlink_path" 2>&1)
    
    # Should handle symlinks
    assert_equal 1 "$(echo "$output" | grep -c "Processing")" "Should process symlinked AppImage"
}

test_concurrent_installation() {
    log_info "Testing concurrent installation prevention"
    
    # This test is conceptual - in practice, you'd need to test with actual concurrent processes
    # For now, we'll just verify that the basic installation works
    local test_appimage="$TEST_HOME/Downloads/ConcurrentTest.AppImage"
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$test_appimage"
    
    echo "0" | "$TEST_ENV_DIR/bin/ai_test" install "$test_appimage" &>/dev/null
    
    assert_file_exists "$TEST_DESKTOP_DIR/ConcurrentTest.desktop" "Basic installation should work"
}

# Run all tests
run_edge_case_tests() {
    log_info "Running edge case tests"
    
    # Initialize test framework
    init_test_framework
    
    # Run individual test functions
    test_invalid_appimage_path
    test_non_executable_appimage
    test_missing_desktop_directory
    test_corrupted_config_file
    test_missing_version_file
    test_empty_version_file
    test_invalid_version_format
    test_permission_denied_scenarios
    test_case_insensitive_search
    test_special_characters_in_names
    test_very_long_paths
    test_multiple_appimages_same_name
    test_symlink_handling
    test_concurrent_installation
    
    # Print summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_edge_case_tests
fi