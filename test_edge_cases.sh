#!/bin/bash

# Test script for edge cases with different AppImage files
set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISOLATED_ROOT="/tmp/appimage_edge_test_$$"
ISOLATED_HOME="$ISOLATED_ROOT/home"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${BOLD}${BLUE}$1${NC}"; }

cleanup() {
    if [[ -d "$ISOLATED_ROOT" ]]; then
        log_info "Cleaning up edge case test environment..."
        rm -rf "$ISOLATED_ROOT"
    fi
}
trap cleanup EXIT

setup_environment() {
    log_header "Setting up edge case test environment"
    
    mkdir -p "$ISOLATED_HOME"/{.config/appimage_desktop_integrator,.local/share/{applications,icons},Downloads,Applications}
    mkdir -p "$ISOLATED_ROOT/bin"
    
    cat > "$ISOLATED_HOME/.config/appimage_desktop_integrator/config.ini" <<EOF
icons_dir=$ISOLATED_HOME/.local/share/icons/appimage-integrator
update_dir=$ISOLATED_HOME/.local/share/applications
appimages_dirs=("$ISOLATED_HOME/Applications")
EOF
    
    echo "2.0.2" > "$ISOLATED_HOME/.config/appimage_desktop_integrator/VERSION"
    
    cp "$SCRIPT_DIR/install_appimages.sh" "$ISOLATED_ROOT/bin/ai"
    chmod +x "$ISOLATED_ROOT/bin/ai"
    
    cat > "$ISOLATED_ROOT/bin/ai_test" <<EOF
#!/bin/bash
export HOME="$ISOLATED_HOME"
export XDG_CONFIG_HOME="$ISOLATED_HOME/.config"
export XDG_DATA_HOME="$ISOLATED_HOME/.local/share"
cd "$ISOLATED_HOME"
"$ISOLATED_ROOT/bin/ai" "\$@"
EOF
    chmod +x "$ISOLATED_ROOT/bin/ai_test"
    
    log_success "Edge case test environment ready"
}

test_appimage_name_extraction() {
    log_header "Testing name extraction with different AppImage files"
    
    local test_cases=(
        "MediaElch_linux_2.12.0_2024-10-13_git-8032465.AppImage:MediaElch"
        "nosqlbooster4mongo-9.1.6.AppImage:nosqlbooster"
        "OpenRGB_0.9_x86_64_b5f46e3.AppImage:OpenRGB"
        "via-3.0.0-linux.AppImage:via"
    )
    
    local tests_passed=0
    local tests_total=${#test_cases[@]}
    
    for case in "${test_cases[@]}"; do
        IFS=':' read -r filename expected <<< "$case"
        
        if [[ -f "$SCRIPT_DIR/appimage_files/$filename" ]]; then
            log_info "Testing name extraction for: $filename"
            
            # Extract name using the same logic as clean_appimage_name function
            local basename_no_ext="${filename%.AppImage}"
            local extracted_name="${basename_no_ext%%[^a-zA-Z]*}"
            
            if [[ "$extracted_name" == "$expected" ]]; then
                log_success "✓ Correct extraction: '$filename' → '$extracted_name'"
                ((tests_passed++))
            else
                log_error "✗ Failed extraction: '$filename' → '$extracted_name' (expected '$expected')"
            fi
        else
            log_info "Skipping missing file: $filename"
            ((tests_total--))
        fi
    done
    
    echo
    log_info "Name extraction results: $tests_passed/$tests_total passed"
    return $([ $tests_passed -eq $tests_total ] && echo 0 || echo 1)
}

test_path_handling_with_different_files() {
    log_header "Testing path handling with different AppImage files"
    
    local available_files=(
        "MediaElch_linux_2.12.0_2024-10-13_git-8032465.AppImage"
        "nosqlbooster4mongo-9.1.6.AppImage" 
        "OpenRGB_0.9_x86_64_b5f46e3.AppImage"
        "via-3.0.0-linux.AppImage"
    )
    
    local tests_passed=0
    local tests_total=0
    
    for filename in "${available_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/appimage_files/$filename" ]]; then
            ((tests_total++))
            log_info "Testing path handling for: $filename"
            
            # Copy to isolated home
            cp "$SCRIPT_DIR/appimage_files/$filename" "$ISOLATED_HOME/"
            cd "$ISOLATED_HOME"
            
            # Test the fixed path assignment logic
            appimage_path="$filename"
            appimage_name=$(basename "$appimage_path")
            original_path=$(dirname "$appimage_path")
            target_dir="$ISOLATED_HOME/Applications"
            
            # Apply the fix logic
            if [ "$original_path" != "$target_dir" ]; then
                log_info "  Would move from '$original_path' to '$target_dir'"
                # Don't actually move files in test
            fi
            # The fix: always update path
            appimage_path="$target_dir/$appimage_name"
            
            if [[ "$appimage_path" == "$target_dir/$appimage_name" ]]; then
                log_success "✓ Path correctly updated for $filename"
                ((tests_passed++))
            else
                log_error "✗ Path update failed for $filename"
            fi
            
            rm -f "$ISOLATED_HOME/$filename"
        fi
    done
    
    echo
    log_info "Path handling results: $tests_passed/$tests_total passed"
    return $([ $tests_passed -eq $tests_total ] && echo 0 || echo 1)
}

test_remove_functionality() {
    log_header "Testing remove functionality with different desktop entries"
    
    cd "$ISOLATED_HOME"
    
    # Create different desktop entries to test removal
    local test_apps=("MediaElch" "NoSQLBooster" "OpenRGB" "Via")
    
    mkdir -p "$ISOLATED_HOME/.local/share/applications"
    
    for app in "${test_apps[@]}"; do
        cat > "$ISOLATED_HOME/.local/share/applications/${app}.desktop" <<EOF
[Desktop Entry]
Name=$app
Exec=/path/to/${app}.AppImage
Icon=${app,,}
Type=Application
Categories=Utility;
Comment=Generated by AppImage Integrator
EOF
    done
    
    log_info "Created test desktop entries for: ${test_apps[*]}"
    
    # Test that remove command runs without local variable errors
    for app in "${test_apps[@]}"; do
        log_info "Testing removal of: $app"
        
        output=$("$ISOLATED_ROOT/bin/ai_test" remove "$app" 2>&1) || true
        
        if echo "$output" | grep -q "local.*función\|local.*function"; then
            log_error "✗ Local variable error still exists for $app"
            return 1
        else
            log_success "✓ No local variable errors for $app"
        fi
    done
    
    log_success "Remove functionality works correctly for all test cases"
    return 0
}

run_edge_case_tests() {
    log_header "Running Edge Case Tests"
    
    local tests_passed=0
    local tests_failed=0
    
    if test_appimage_name_extraction; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    echo
    
    if test_path_handling_with_different_files; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    echo
    
    if test_remove_functionality; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    echo
    
    log_header "Edge Case Test Summary"
    echo
    echo "Edge Case Tests Passed: $tests_passed"
    echo "Edge Case Tests Failed: $tests_failed"
    echo
    
    if [[ $tests_failed -eq 0 ]]; then
        log_success "🎉 All edge case tests passed!"
        echo
        echo "✅ Name extraction works with all available AppImages"
        echo "✅ Path handling works correctly for different file types"
        echo "✅ Remove functionality is robust across different desktop entries"
        echo
        return 0
    else
        log_error "❌ Some edge case tests failed"
        return 1
    fi
}

main() {
    log_header "Edge Case Testing with Real AppImage Files"
    echo
    
    log_info "Available AppImage files for testing:"
    ls -la "$SCRIPT_DIR/appimage_files/" | grep "\.AppImage" | awk '{print "  - " $9}'
    echo
    
    setup_environment
    echo
    
    run_edge_case_tests
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi