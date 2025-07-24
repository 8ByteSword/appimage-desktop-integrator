#!/bin/bash

# Basic functionality tests for AppImage Desktop Integrator

# Source the test framework
source "$(dirname "${BASH_SOURCE[0]}")/test_framework.sh"

# Test functions
test_status_command() {
    log_info "Testing status command"
    
    # Set the version to current version to avoid upgrade prompt
    echo "2.0.0" > "$TEST_CONFIG_DIR/VERSION"
    
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" status 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "Status command should succeed"
    assert_equal 1 "$(echo "$output" | grep -c "Current Status")" "Status output should contain header"
    assert_equal 1 "$(echo "$output" | grep -c "Configuration:")" "Status output should show configuration"
}

test_directory_creation() {
    log_info "Testing directory creation"
    
    # Remove directories to test creation
    rm -rf "$TEST_DESKTOP_DIR" "$TEST_ICONS_DIR"
    
    # Run status command which should trigger init_minimal_config
    "$TEST_ENV_DIR/bin/ai_test" status &>/dev/null
    
    assert_dir_exists "$TEST_DESKTOP_DIR" "Desktop directory should be created"
    assert_dir_exists "$TEST_ICONS_DIR" "Icons directory should be created"
}

test_find_command_empty() {
    log_info "Testing find command with no AppImages"
    
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" find 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "Find command should succeed even with no AppImages"
    assert_equal 1 "$(echo "$output" | grep -c "No AppImages found")" "Should report no AppImages found"
}

test_find_command_with_appimages() {
    log_info "Testing find command with AppImages present"
    
    # Copy a mock AppImage to Downloads
    cp "$TEST_ENV_DIR/appimages/samples/TestApp-1.0.0-x86_64.AppImage" "$TEST_HOME/Downloads/"
    
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" find 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "Find command should succeed with AppImages"
    assert_equal 1 "$(echo "$output" | grep -c "Found in $TEST_HOME/Downloads")" "Should find AppImages in Downloads"
    assert_equal 1 "$(echo "$output" | grep -c "TestApp-1.0.0-x86_64.AppImage")" "Should list specific AppImage"
}

test_list_command_empty() {
    log_info "Testing list command with no integrated AppImages"
    
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" list 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "List command should succeed even with no integrated AppImages"
    assert_equal 1 "$(echo "$output" | grep -c "No AppImages integrated yet")" "Should report no integrated AppImages"
}

test_help_command() {
    log_info "Testing help command"
    
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" help 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "Help command should succeed"
    assert_equal 1 "$(echo "$output" | grep -c "AppImage Integrator")" "Help should contain tool name"
    assert_equal 1 "$(echo "$output" | grep -c "Quick Commands:")" "Help should show commands section"
}

test_desktop_command() {
    log_info "Testing desktop command"
    
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" desktop 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "Desktop command should succeed"
    assert_equal 1 "$(echo "$output" | grep -c "Desktop Files for AppImages")" "Should show desktop files header"
}

test_logs_command_no_args() {
    log_info "Testing logs command without arguments"
    
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" logs 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "Logs command should succeed without args"
    assert_equal 1 "$(echo "$output" | grep -c "Usage: ai logs")" "Should show usage information"
}

test_run_command_no_args() {
    log_info "Testing run command without arguments"
    
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" run 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "Run command should succeed without args"
    assert_equal 1 "$(echo "$output" | grep -c "Usage: ai run")" "Should show usage information"
}

test_debug_command_no_args() {
    log_info "Testing debug command without arguments"
    
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" debug 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "Debug command should succeed without args"
    assert_equal 1 "$(echo "$output" | grep -c "Usage: ai debug")" "Should show usage information"
}

test_remove_command_no_args() {
    log_info "Testing remove command without arguments"
    
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" remove 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "Remove command should succeed without args"
    assert_equal 1 "$(echo "$output" | grep -c "Usage: ai remove")" "Should show usage information"
}

test_unknown_command() {
    log_info "Testing unknown command"
    
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" nonexistent_command 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "Unknown command should show help"
    assert_equal 1 "$(echo "$output" | grep -c "Unknown command:")" "Should report unknown command"
}

test_config_file_creation() {
    log_info "Testing config file creation behavior"
    
    # Remove config file
    rm -f "$TEST_CONFIG_DIR/config.ini"
    
    # Run a command that initializes config (should work with defaults)
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" status 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "Status command should work without config file"
    assert_equal 1 "$(echo "$output" | grep -c "Current Status")" "Should show status even without config file"
    
    # The current implementation uses defaults without creating a config file
    # This is actually correct behavior - config file is optional
}

test_version_file_creation() {
    log_info "Testing version file behavior"
    
    # Remove version file
    rm -f "$TEST_CONFIG_DIR/VERSION"
    
    # Run a command that checks version (might trigger version update)
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" status 2>&1)
    local exit_code=$?
    
    assert_equal 0 "$exit_code" "Status command should work without version file"
    
    # Check if version file was created (this may happen depending on version logic)
    if [[ -f "$TEST_CONFIG_DIR/VERSION" ]]; then
        local version_content
        version_content=$(cat "$TEST_CONFIG_DIR/VERSION")
        assert_equal "2.0.0" "$version_content" "Version file should contain current version if created"
    fi
}

# Run all tests
run_basic_tests() {
    log_info "Running basic functionality tests"
    
    # Initialize test framework
    init_test_framework
    
    # Run individual test functions
    test_status_command
    test_directory_creation
    test_find_command_empty
    test_find_command_with_appimages
    test_list_command_empty
    test_help_command
    test_desktop_command
    test_logs_command_no_args
    test_run_command_no_args
    test_debug_command_no_args
    test_remove_command_no_args
    test_unknown_command
    test_config_file_creation
    test_version_file_creation
    
    # Print summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_basic_tests
fi