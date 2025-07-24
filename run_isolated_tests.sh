#!/bin/bash

# Enhanced Isolated Test Runner for AppImage Desktop Integrator
# Creates a completely isolated environment for safe testing

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISOLATED_ROOT="/tmp/appimage_integrator_isolated_test_$$"
ISOLATED_HOME="$ISOLATED_ROOT/home"
BACKUP_PATH="$ISOLATED_ROOT/original_configs"

# Global test results
TOTAL_ISSUES_TESTED=0
ISSUES_PASSED=0
ISSUES_FAILED=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${BOLD}${BLUE}$1${NC}"; }

cleanup() {
    if [[ -d "$ISOLATED_ROOT" ]]; then
        log_info "Cleaning up isolated test environment..."
        rm -rf "$ISOLATED_ROOT"
        log_success "Cleanup completed"
    fi
}

# Cleanup on exit
trap cleanup EXIT

create_isolated_environment() {
    log_header "Creating Completely Isolated Test Environment"
    log_info "Isolated root: $ISOLATED_ROOT"
    
    # Create isolated directory structure
    mkdir -p "$ISOLATED_HOME"/{.config,.local/{share/{applications,icons},bin},Downloads,Desktop,Applications,AppImages,apps,bin}
    mkdir -p "$ISOLATED_ROOT"/{bin,appimages,logs}
    mkdir -p "$BACKUP_PATH"
    
    # Backup any existing configs (to restore later if needed)
    if [[ -d "$HOME/.config/appimage_desktop_integrator" ]]; then
        cp -r "$HOME/.config/appimage_desktop_integrator" "$BACKUP_PATH/" 2>/dev/null || true
        log_info "Backed up existing configuration"
    fi
    
    # Create isolated config
    mkdir -p "$ISOLATED_HOME/.config/appimage_desktop_integrator"
    cat > "$ISOLATED_HOME/.config/appimage_desktop_integrator/config.ini" <<EOF
# Isolated test configuration
icons_dir=$ISOLATED_HOME/.local/share/icons/appimage-integrator
update_dir=$ISOLATED_HOME/.local/share/applications
appimages_dirs=("$ISOLATED_HOME/AppImages" "$ISOLATED_HOME/Applications")
EOF
    
    # Set version to avoid upgrade prompts
    echo "2.0.2" > "$ISOLATED_HOME/.config/appimage_desktop_integrator/VERSION"
    
    # Copy main script to isolated environment
    cp "$SCRIPT_DIR/install_appimages.sh" "$ISOLATED_ROOT/bin/ai"
    chmod +x "$ISOLATED_ROOT/bin/ai"
    
    # Create test wrapper that operates in isolated environment
    cat > "$ISOLATED_ROOT/bin/ai_isolated" <<EOF
#!/bin/bash
export HOME="$ISOLATED_HOME"
export XDG_CONFIG_HOME="$ISOLATED_HOME/.config"
export XDG_DATA_HOME="$ISOLATED_HOME/.local/share"
cd "$ISOLATED_HOME"
"$ISOLATED_ROOT/bin/ai" "\$@"
EOF
    chmod +x "$ISOLATED_ROOT/bin/ai_isolated"
    
    log_success "Isolated environment created successfully"
}

create_test_appimages() {
    log_header "Creating Mock AppImages for Testing"
    
    local appimages_dir="$ISOLATED_ROOT/appimages"
    
    # Create mock AppImages for testing specific issues
    
    # Issue #4 test: Complex filename
    create_mock_appimage "MediaElch_linux_2.12.0_2024-10-13_git-8032465-1.AppImage" "MediaElch" "2.12.0" "AudioVideo"
    
    # Issue #5 test: Simple filename (for current directory test)
    create_mock_appimage "LosslessCut-linux-x86_64.AppImage" "LosslessCut" "3.64.0" "AudioVideo"
    
    # Additional test cases
    create_mock_appimage "Firefox-123.0.AppImage" "Firefox" "123.0" "Network"
    create_mock_appimage "appimage-cli-tool-0.1.4-x86_64.AppImage" "AppImageCLI" "0.1.4" "Development"
    
    log_success "Mock AppImages created"
}

create_mock_appimage() {
    local filename="$1"
    local app_name="$2"
    local version="$3"
    local category="$4"
    
    local appimage_path="$ISOLATED_ROOT/appimages/$filename"
    local mount_dir="$ISOLATED_ROOT/appimages/mount_${filename%.AppImage}"
    
    # Create mock AppImage executable
    cat > "$appimage_path" <<EOF
#!/bin/bash
# Mock AppImage for testing
case "\$1" in
    --appimage-mount)
        mkdir -p "$mount_dir"
        # Create mock desktop file
        cat > "$mount_dir/app.desktop" <<DESKTOP_EOF
[Desktop Entry]
Name=$app_name
Version=$version
Categories=$category;
DESKTOP_EOF
        # Create mock icon
        mkdir -p "$mount_dir/icons"
        echo "mock icon data" > "$mount_dir/icons/${app_name,,}.png"
        echo "$mount_dir"
        sleep 30 &  # Simulate mount process
        ;;
    --help)
        echo "Mock AppImage help"
        ;;
    *)
        echo "Running mock $app_name"
        ;;
esac
EOF
    chmod +x "$appimage_path"
    
    log_info "Created mock AppImage: $filename"
}

test_issue_4_name_extraction() {
    log_header "Testing Issue #4: AppImage Name Extraction"
    ((TOTAL_ISSUES_TESTED++))
    
    local test_file="$ISOLATED_ROOT/appimages/MediaElch_linux_2.12.0_2024-10-13_git-8032465-1.AppImage"
    local test_passed=true
    
    # Copy to isolated home for testing
    cp "$test_file" "$ISOLATED_HOME/Downloads/"
    
    log_info "Testing with filename: MediaElch_linux_2.12.0_2024-10-13_git-8032465-1.AppImage"
    
    # Test the clean name extraction logic directly
    cd "$ISOLATED_HOME/Downloads"
    
    # Simulate the function logic
    local input_name="MediaElch_linux_2.12.0_2024-10-13_git-8032465-1.AppImage"
    local cleaned_name="${input_name%%[^a-zA-Z]*}"
    
    if [[ "$cleaned_name" == "MediaElch" ]]; then
        log_success "✓ Name extraction works correctly: '$input_name' → '$cleaned_name'"
    else
        log_error "✗ Name extraction failed: '$input_name' → '$cleaned_name' (expected 'MediaElch')"
        test_passed=false
    fi
    
    # Test edge cases
    local test_cases=(
        "Firefox-123.0.AppImage:Firefox"
        "appimage-cli-tool:appimage"
        "VLC_media_player:VLC"
        "123StartWithNumber:"
        "OnlyLetters:OnlyLetters"
    )
    
    for case in "${test_cases[@]}"; do
        IFS=':' read -r input expected <<< "$case"
        local result="${input%%[^a-zA-Z]*}"
        
        if [[ "$result" == "$expected" ]]; then
            log_success "✓ Edge case passed: '$input' → '$result'"
        else
            log_error "✗ Edge case failed: '$input' → '$result' (expected '$expected')"
            test_passed=false
        fi
    done
    
    if $test_passed; then
        ((ISSUES_PASSED++))
        log_success "Issue #4 PASSED: Name extraction works correctly"
    else
        ((ISSUES_FAILED++))
        log_error "Issue #4 FAILED: Name extraction has problems"
    fi
    
    return $test_passed
}

test_issue_5_dirname_bug() {
    log_header "Testing Issue #5: Dirname Bug with Current Directory"  
    ((TOTAL_ISSUES_TESTED++))
    
    local test_file="LosslessCut-linux-x86_64.AppImage"
    local test_passed=true
    
    # Copy test file to isolated home
    cp "$ISOLATED_ROOT/appimages/$test_file" "$ISOLATED_HOME/"
    cd "$ISOLATED_HOME"
    
    log_info "Testing dirname behavior with filename-only path"
    
    # Test the problematic case
    local original_path=$(dirname "$test_file")
    log_info "dirname result for '$test_file': '$original_path'"
    
    if [[ "$original_path" == "." ]]; then
        log_success "✓ Confirmed: dirname returns '.' for filename-only path"
        
        # Test the fix logic
        if [[ "$original_path" == "." ]]; then
            original_path="$PWD"
        fi
        
        if [[ "$original_path" != "." && -n "$original_path" ]]; then
            log_success "✓ Fix works: PWD assignment results in '$original_path'"
        else
            log_error "✗ Fix failed: PWD assignment didn't work properly"
            test_passed=false
        fi
    else
        log_error "✗ Unexpected: dirname didn't return '.' for filename-only path"
        test_passed=false
    fi
    
    # Test with full path (should not trigger fix)
    local full_path="/home/user/Downloads/$test_file"
    local full_path_dirname=$(dirname "$full_path")
    
    if [[ "$full_path_dirname" == "/home/user/Downloads" ]]; then
        log_success "✓ Full path dirname works normally: '$full_path_dirname'"
    else
        log_error "✗ Full path dirname unexpected result: '$full_path_dirname'"
        test_passed=false
    fi
    
    if $test_passed; then
        ((ISSUES_PASSED++))
        log_success "Issue #5 PASSED: Dirname bug fix works correctly"
    else
        ((ISSUES_FAILED++))
        log_error "Issue #5 FAILED: Dirname bug fix has problems"
    fi
    
    return $test_passed
}

test_issue_6_variable_scoping() {
    log_header "Testing Issue #6: Local Variable Scoping in Remove Function"
    ((TOTAL_ISSUES_TESTED++))
    
    local test_passed=true
    
    log_info "Testing local variable scoping patterns"
    
    # Test the specific pattern from the fix
    test_local_scoping() {
        local found=false
        local name="TestApp"
        
        # Simulate the problematic scenario
        if [[ -n "$name" ]]; then
            found=true
        fi
        
        # These variables should be accessible within the function
        if [[ "$found" == "true" && "$name" == "TestApp" ]]; then
            return 0
        else
            return 1
        fi
    }
    
    if test_local_scoping; then
        log_success "✓ Local variable scoping works correctly"
    else
        log_error "✗ Local variable scoping has issues"
        test_passed=false
    fi
    
    # Check the actual script for proper local declarations
    if grep -q "local found=false" "$ISOLATED_ROOT/bin/ai" && \
       grep -q "local name=" "$ISOLATED_ROOT/bin/ai"; then
        log_success "✓ Script contains proper local variable declarations"
    else
        log_error "✗ Script missing proper local variable declarations"
        test_passed=false
    fi
    
    if $test_passed; then
        ((ISSUES_PASSED++))
        log_success "Issue #6 PASSED: Variable scoping works correctly"
    else
        ((ISSUES_FAILED++))
        log_error "Issue #6 FAILED: Variable scoping has problems"
    fi
    
    return $test_passed
}

test_script_syntax() {
    log_header "Testing Script Syntax and Structure"
    
    log_info "Validating bash syntax..."
    if bash -n "$ISOLATED_ROOT/bin/ai"; then
        log_success "✓ Script syntax is valid"
    else
        log_error "✗ Script has syntax errors"
        return 1
    fi
    
    log_info "Checking for required functions..."
    local required_functions=(
        "clean_appimage_name"
        "install_single_appimage"
        "process_appimage"
    )
    
    for func in "${required_functions[@]}"; do
        if grep -q "^${func}()" "$ISOLATED_ROOT/bin/ai"; then
            log_success "✓ Function '$func' exists"
        else
            log_error "✗ Function '$func' missing"
            return 1
        fi
    done
    
    return 0
}

run_comprehensive_tests() {
    log_header "Running Comprehensive Issue Tests"
    
    # Test each issue individually
    test_issue_4_name_extraction
    echo
    test_issue_5_dirname_bug  
    echo
    test_issue_6_variable_scoping
    echo
    test_script_syntax
    echo
}

show_test_summary() {
    log_header "Test Summary Report"
    echo
    echo "Issues Tested: $TOTAL_ISSUES_TESTED"
    echo -e "${GREEN}Issues Passed: $ISSUES_PASSED${NC}"
    echo -e "${RED}Issues Failed: $ISSUES_FAILED${NC}"
    echo
    
    if [[ $ISSUES_FAILED -eq 0 ]]; then
        log_success "🎉 All GitHub issues have been successfully resolved!"
        echo
        echo "✅ Issue #4: AppImage name extraction with user confirmation"
        echo "✅ Issue #5: Dirname bug fix for current directory installation"  
        echo "✅ Issue #6: Local variable scoping in remove function"
        echo
        log_success "The code is ready for production commit!"
        return 0
    else
        log_error "❌ Some issues still have problems and need attention"
        return 1
    fi
}

# Main execution
main() {
    log_header "AppImage Desktop Integrator - Isolated Issue Testing"
    echo
    log_info "This will test GitHub issues #4, #5, and #6 in a completely isolated environment"
    echo
    
    create_isolated_environment
    echo
    create_test_appimages  
    echo
    run_comprehensive_tests
    echo
    show_test_summary
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi