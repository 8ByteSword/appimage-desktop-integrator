#!/bin/bash

# AppImage Desktop Integrator Test Framework
# Creates isolated test environments for safe testing

# Note: Removing set -e to prevent early exit on test failures
set -uo pipefail

# Test framework configuration
TEST_ROOT_DIR="/tmp/appimage_integrator_tests"
TEST_SESSION_ID="test_$$_$(date +%s)"
TEST_ENV_DIR="$TEST_ROOT_DIR/$TEST_SESSION_ID"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test assertion functions
assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    ((TESTS_TOTAL++))
    
    if [[ "$expected" == "$actual" ]]; then
        ((TESTS_PASSED++))
        log_success "PASS: $message"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "FAIL: $message"
        log_error "  Expected: '$expected'"
        log_error "  Actual:   '$actual'"
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local message="${2:-File should exist: $file_path}"
    
    ((TESTS_TOTAL++))
    
    if [[ -f "$file_path" ]]; then
        ((TESTS_PASSED++))
        log_success "PASS: $message"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "FAIL: $message"
        return 1
    fi
}

assert_file_not_exists() {
    local file_path="$1"
    local message="${2:-File should not exist: $file_path}"
    
    ((TESTS_TOTAL++))
    
    if [[ ! -f "$file_path" ]]; then
        ((TESTS_PASSED++))
        log_success "PASS: $message"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "FAIL: $message"
        return 1
    fi
}

assert_dir_exists() {
    local dir_path="$1"
    local message="${2:-Directory should exist: $dir_path}"
    
    ((TESTS_TOTAL++))
    
    if [[ -d "$dir_path" ]]; then
        ((TESTS_PASSED++))
        log_success "PASS: $message"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "FAIL: $message"
        return 1
    fi
}

assert_command_succeeds() {
    local command="$1"
    local message="${2:-Command should succeed: $command}"
    
    ((TESTS_TOTAL++))
    
    if eval "$command" &>/dev/null; then
        ((TESTS_PASSED++))
        log_success "PASS: $message"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "FAIL: $message"
        return 1
    fi
}

assert_command_fails() {
    local command="$1"
    local message="${2:-Command should fail: $command}"
    
    ((TESTS_TOTAL++))
    
    if eval "$command" &>/dev/null; then
        ((TESTS_FAILED++))
        log_error "FAIL: $message"
        return 1
    else
        ((TESTS_PASSED++))
        log_success "PASS: $message"
        return 0
    fi
}

# Setup isolated test environment
setup_test_environment() {
    log_info "Setting up test environment: $TEST_ENV_DIR"
    
    # Clean up any existing test environment
    if [[ -d "$TEST_ENV_DIR" ]]; then
        rm -rf "$TEST_ENV_DIR"
    fi
    
    # Create test directories
    mkdir -p "$TEST_ENV_DIR/home/.config/appimage_desktop_integrator"
    mkdir -p "$TEST_ENV_DIR/home/.local/share/applications"
    mkdir -p "$TEST_ENV_DIR/home/.local/share/icons/appimage-integrator"
    mkdir -p "$TEST_ENV_DIR/home/Downloads"
    mkdir -p "$TEST_ENV_DIR/home/Desktop"
    mkdir -p "$TEST_ENV_DIR/home/Applications"
    mkdir -p "$TEST_ENV_DIR/home/AppImages"
    mkdir -p "$TEST_ENV_DIR/home/apps"
    mkdir -p "$TEST_ENV_DIR/home/.local/bin"
    mkdir -p "$TEST_ENV_DIR/opt"
    mkdir -p "$TEST_ENV_DIR/appimages/samples"
    mkdir -p "$TEST_ENV_DIR/bin"
    
    # Set up environment variables for isolated testing
    export TEST_HOME="$TEST_ENV_DIR/home"
    export TEST_CONFIG_DIR="$TEST_HOME/.config/appimage_desktop_integrator"
    export TEST_DESKTOP_DIR="$TEST_HOME/.local/share/applications"
    export TEST_ICONS_DIR="$TEST_HOME/.local/share/icons/appimage-integrator"
    
    # Create a test-specific config
    cat > "$TEST_CONFIG_DIR/config.ini" <<EOF
# Test configuration
icons_dir=$TEST_ICONS_DIR
update_dir=$TEST_DESKTOP_DIR
appimages_dirs=("$TEST_HOME/AppImages" "$TEST_HOME/Applications" "$TEST_HOME/apps")
EOF
    
    # Create test version file (set to current version to avoid upgrade prompts)
    echo "2.0.0" > "$TEST_CONFIG_DIR/VERSION"
    
    # Create wrapper script for testing
    local wrapper_dir="$TEST_CONFIG_DIR/bin"
    mkdir -p "$wrapper_dir"
    cat > "$wrapper_dir/appimage-run-wrapper.sh" <<'EOF'
#!/bin/bash
# Test wrapper script
APPIMAGE_PATH="$1"
shift
APPIMAGE_NAME=$(basename "$APPIMAGE_PATH" .AppImage)
LOGS_DIR="$HOME/.config/appimage_desktop_integrator/logs"
mkdir -p "$LOGS_DIR"
LOG_FILE="$LOGS_DIR/${APPIMAGE_NAME}.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Test run: $APPIMAGE_NAME" >> "$LOG_FILE"
echo "Test execution completed for $APPIMAGE_NAME"
EOF
    chmod +x "$wrapper_dir/appimage-run-wrapper.sh"
    
    log_success "Test environment created successfully"
}

# Create mock AppImage files for testing
create_mock_appimages() {
    local samples_dir="$TEST_ENV_DIR/appimages/samples"
    
    log_info "Creating mock AppImage files"
    
    # Create various mock AppImage files
    local appimages=(
        "TestApp-1.0.0-x86_64.AppImage"
        "Firefox-120.0.AppImage"
        "VIA-3.0.0-linux.AppImage"
        "VSCode-1.85.0.AppImage"
        "Simple.AppImage"
        "Electron-App-2.0.0.AppImage"
    )
    
    for appimage in "${appimages[@]}"; do
        local app_path="$samples_dir/$appimage"
        
        # Create a basic shell script that pretends to be an AppImage
        cat > "$app_path" <<EOF
#!/bin/bash
# Mock AppImage: $appimage
case "\$1" in
    --appimage-mount)
        # Mock mount point
        echo "$TEST_ENV_DIR/mock_mount_\$(basename "\$0" .AppImage)"
        mkdir -p "$TEST_ENV_DIR/mock_mount_\$(basename "\$0" .AppImage)"
        
        # Create mock desktop file in mount point
        cat > "$TEST_ENV_DIR/mock_mount_\$(basename "\$0" .AppImage)/app.desktop" <<'DESKTOP_EOF'
[Desktop Entry]
Name=\$(basename "\$0" .AppImage | sed 's/-[0-9].*//g')
Version=1.0.0
Categories=Utility;Application;
DESKTOP_EOF
        
        # Create mock icon
        touch "$TEST_ENV_DIR/mock_mount_\$(basename "\$0" .AppImage)/icon.png"
        
        # Keep running to simulate mount
        sleep 1000 &
        echo \$!
        ;;
    --help)
        echo "Mock AppImage help for \$(basename "\$0")"
        ;;
    *)
        echo "Running mock AppImage: \$(basename "\$0")"
        ;;
esac
EOF
        
        chmod +x "$app_path"
    done
    
    log_success "Created ${#appimages[@]} mock AppImage files"
}

# Copy actual scripts to test environment
setup_test_scripts() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local test_bin_dir="$TEST_ENV_DIR/bin"
    
    log_info "Setting up test scripts"
    
    # Copy main script
    cp "$script_dir/install_appimages.sh" "$test_bin_dir/install_appimages"
    chmod +x "$test_bin_dir/install_appimages"
    
    # The ai_test wrapper sets HOME appropriately for the test environment
    
    # Create test-specific version that uses test environment
    cat > "$test_bin_dir/ai_test" <<EOF
#!/bin/bash
# Test version of ai command
export HOME="$TEST_HOME"
export PATH="$TEST_ENV_DIR/bin:\$PATH"
"$test_bin_dir/install_appimages" "\$@"
EOF
    chmod +x "$test_bin_dir/ai_test"
    
    log_success "Test scripts configured"
}

# Clean up test environment
cleanup_test_environment() {
    log_info "Cleaning up test environment"
    
    # Kill any background processes from mock AppImages
    pkill -f "sleep 1000" 2>/dev/null || true
    
    # Remove test directory
    if [[ -d "$TEST_ENV_DIR" ]]; then
        rm -rf "$TEST_ENV_DIR"
    fi
    
    log_success "Test environment cleaned up"
}

# Test result summary
print_test_summary() {
    echo ""
    echo "=================================="
    echo "Test Results Summary"
    echo "=================================="
    echo "Total Tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo "=================================="
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        return 0
    else
        log_error "Some tests failed!"
        return 1
    fi
}

# Initialize test framework
init_test_framework() {
    log_info "Initializing AppImage Integrator Test Framework"
    log_info "Test Session ID: $TEST_SESSION_ID"
    
    # Setup test environment
    setup_test_environment
    create_mock_appimages
    setup_test_scripts
    
    log_success "Test framework initialized successfully"
}

# Export functions for use in test files
export -f log_info log_success log_warning log_error
export -f assert_equal assert_file_exists assert_file_not_exists assert_dir_exists
export -f assert_command_succeeds assert_command_fails
export -f setup_test_environment create_mock_appimages setup_test_scripts
export -f cleanup_test_environment print_test_summary init_test_framework

# Export test environment variables
export TEST_ENV_DIR TEST_HOME TEST_CONFIG_DIR TEST_DESKTOP_DIR TEST_ICONS_DIR
export TESTS_PASSED TESTS_FAILED TESTS_TOTAL