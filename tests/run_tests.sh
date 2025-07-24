#!/bin/bash

# AppImage Desktop Integrator Test Runner
# Runs all test suites and provides comprehensive reporting

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
OVERALL_TESTS_PASSED=0
OVERALL_TESTS_FAILED=0
OVERALL_TESTS_TOTAL=0

# Configuration
VERBOSE=false
CLEANUP=true
PARALLEL=false
SELECTED_SUITE=""

# Help function
show_help() {
    echo "AppImage Desktop Integrator Test Runner"
    echo ""
    echo "Usage: $0 [OPTIONS] [SUITE]"
    echo ""
    echo "Options:"
    echo "  -v, --verbose       Enable verbose output"
    echo "  -n, --no-cleanup    Don't cleanup test environments after running"
    echo "  -p, --parallel      Run test suites in parallel (experimental)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Available test suites:"
    echo "  basic              Basic functionality tests"
    echo "  appimage           AppImage processing and integration tests"
    echo "  edge               Edge cases and error handling tests"
    echo "  chaos              Chaotic real-world AppImage scenarios"
    echo "  all                Run all test suites (default)"
    echo ""
    echo "Examples:"
    echo "  $0                 # Run all test suites"
    echo "  $0 basic           # Run only basic functionality tests"
    echo "  $0 -v edge         # Run edge case tests with verbose output"
    echo "  $0 --no-cleanup    # Run all tests without cleaning up"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--no-cleanup)
                CLEANUP=false
                shift
                ;;
            -p|--parallel)
                PARALLEL=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            basic|appimage|edge|chaos|all)
                SELECTED_SUITE="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default to running all suites
    if [[ -z "$SELECTED_SUITE" ]]; then
        SELECTED_SUITE="all"
    fi
}

# Logging functions
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

log_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
}

# Run a single test suite
run_test_suite() {
    local suite_name="$1"
    local suite_file="$2"
    
    log_header "Running $suite_name tests..."
    echo "========================================"
    
    ((TOTAL_SUITES++))
    
    local start_time=$(date +%s)
    local output_file="/tmp/test_output_$$.txt"
    
    if [[ "$VERBOSE" == "true" ]]; then
        if bash "$suite_file"; then
            ((PASSED_SUITES++))
            log_success "$suite_name tests PASSED"
        else
            ((FAILED_SUITES++))
            log_error "$suite_name tests FAILED"
        fi
    else
        if bash "$suite_file" > "$output_file" 2>&1; then
            ((PASSED_SUITES++))
            log_success "$suite_name tests PASSED"
            
            # Extract test counts from output
            local passed=$(grep -o "Passed: [0-9]\+" "$output_file" | grep -o "[0-9]\+" || echo "0")
            local failed=$(grep -o "Failed: [0-9]\+" "$output_file" | grep -o "[0-9]\+" || echo "0")
            local total=$(grep -o "Total Tests: [0-9]\+" "$output_file" | grep -o "[0-9]\+" || echo "0")
            
            OVERALL_TESTS_PASSED=$((OVERALL_TESTS_PASSED + passed))
            OVERALL_TESTS_FAILED=$((OVERALL_TESTS_FAILED + failed))
            OVERALL_TESTS_TOTAL=$((OVERALL_TESTS_TOTAL + total))
            
            echo "  Tests: $passed passed, $failed failed, $total total"
        else
            ((FAILED_SUITES++))
            log_error "$suite_name tests FAILED"
            
            # Show last few lines of output for debugging
            echo "Last 10 lines of output:"
            tail -n 10 "$output_file" 2>/dev/null || echo "No output available"
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "Duration: ${duration}s"
    echo ""
    
    # Cleanup output file
    rm -f "$output_file"
}

# Run test suites in parallel
run_parallel_suites() {
    local suites=("$@")
    local pids=()
    local results=()
    
    log_info "Running test suites in parallel..."
    
    # Start all test suites
    for suite in "${suites[@]}"; do
        case $suite in
            basic)
                run_test_suite "Basic Functionality" "$SCRIPT_DIR/test_basic_functionality.sh" &
                pids+=($!)
                ;;
            appimage)
                run_test_suite "AppImage Processing" "$SCRIPT_DIR/test_appimage_processing.sh" &
                pids+=($!)
                ;;
            edge)
                run_test_suite "Edge Cases" "$SCRIPT_DIR/test_edge_cases.sh" &
                pids+=($!)
                ;;
            chaos)
                run_test_suite "Chaotic Scenarios" "$SCRIPT_DIR/test_chaotic_appimage_scenarios.sh" &
                pids+=($!)
                ;;
        esac
    done
    
    # Wait for all to complete
    for pid in "${pids[@]}"; do
        if wait "$pid"; then
            results+=(0)
        else
            results+=(1)
        fi
    done
    
    # Process results
    local i=0
    for suite in "${suites[@]}"; do
        ((TOTAL_SUITES++))
        if [[ ${results[i]} -eq 0 ]]; then
            ((PASSED_SUITES++))
        else
            ((FAILED_SUITES++))
        fi
        ((i++))
    done
}

# Run test suites sequentially
run_sequential_suites() {
    local suites=("$@")
    
    for suite in "${suites[@]}"; do
        case $suite in
            basic)
                run_test_suite "Basic Functionality" "$SCRIPT_DIR/test_basic_functionality.sh"
                ;;
            appimage)
                run_test_suite "AppImage Processing" "$SCRIPT_DIR/test_appimage_processing.sh"
                ;;
            edge)
                run_test_suite "Edge Cases" "$SCRIPT_DIR/test_edge_cases.sh"
                ;;
            chaos)
                run_test_suite "Chaotic Scenarios" "$SCRIPT_DIR/test_chaotic_appimage_scenarios.sh"
                ;;
            *)
                log_warning "Unknown test suite: $suite"
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running on Linux
    if [[ "$(uname)" != "Linux" ]]; then
        log_error "Tests must be run on Linux"
        exit 1
    fi
    
    # Check if required commands are available
    local required_commands=("bash" "grep" "sed" "awk" "find" "mkdir" "rm" "cp" "mv" "chmod")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        exit 1
    fi
    
    # Check if test files exist
    local test_files=(
        "$SCRIPT_DIR/test_framework.sh"
        "$SCRIPT_DIR/test_basic_functionality.sh"
        "$SCRIPT_DIR/test_appimage_processing.sh"
        "$SCRIPT_DIR/test_edge_cases.sh"
    )
    
    for file in "${test_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Missing test file: $file"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Print overall summary
print_summary() {
    echo ""
    log_header "==============================================="
    log_header "Overall Test Results Summary"
    log_header "==============================================="
    
    echo "Test Suites:"
    echo -e "  Total: $TOTAL_SUITES"
    echo -e "  ${GREEN}Passed: $PASSED_SUITES${NC}"
    echo -e "  ${RED}Failed: $FAILED_SUITES${NC}"
    echo ""
    
    if [[ $OVERALL_TESTS_TOTAL -gt 0 ]]; then
        echo "Individual Tests:"
        echo -e "  Total: $OVERALL_TESTS_TOTAL"
        echo -e "  ${GREEN}Passed: $OVERALL_TESTS_PASSED${NC}"
        echo -e "  ${RED}Failed: $OVERALL_TESTS_FAILED${NC}"
        echo ""
        
        local success_rate
        success_rate=$(awk "BEGIN {printf \"%.1f\", ($OVERALL_TESTS_PASSED/$OVERALL_TESTS_TOTAL)*100}")
        echo "Success Rate: $success_rate%"
        echo ""
    fi
    
    if [[ $FAILED_SUITES -eq 0 ]]; then
        log_success "All test suites passed! 🎉"
        return 0
    else
        log_error "Some test suites failed! ❌"
        return 1
    fi
}

# Cleanup function
cleanup() {
    if [[ "$CLEANUP" == "true" ]]; then
        log_info "Cleaning up test environments..."
        # Kill any background processes from mock AppImages
        pkill -f "sleep 1000" 2>/dev/null || true
        # Clean up any remaining test directories
        find /tmp/appimage_integrator_tests -maxdepth 1 -type d -name "test_*" -exec rm -rf {} \; 2>/dev/null || true
        log_success "Cleanup completed"
    else
        log_info "Skipping cleanup (test environments preserved for debugging)"
    fi
}

# Main function
main() {
    parse_args "$@"
    
    log_header "AppImage Desktop Integrator Test Runner"
    log_header "========================================"
    echo ""
    
    check_prerequisites
    
    # Determine which suites to run
    local suites_to_run=()
    case $SELECTED_SUITE in
        basic)
            suites_to_run=("basic")
            ;;
        appimage)
            suites_to_run=("appimage")
            ;;
        edge)
            suites_to_run=("edge")
            ;;
        chaos)
            suites_to_run=("chaos")
            ;;
        all)
            suites_to_run=("basic" "appimage" "edge" "chaos")
            ;;
    esac
    
    log_info "Running test suites: ${suites_to_run[*]}"
    echo ""
    
    # Set up signal handlers for cleanup (only for interrupts, not normal exit)
    trap cleanup INT TERM
    
    local start_time=$(date +%s)
    
    # Run tests
    if [[ "$PARALLEL" == "true" && ${#suites_to_run[@]} -gt 1 ]]; then
        run_parallel_suites "${suites_to_run[@]}"
    else
        run_sequential_suites "${suites_to_run[@]}"
    fi
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Print results
    print_summary
    echo "Total Duration: ${total_duration}s"
    
    # Cleanup and return appropriate exit code
    cleanup
    
    if [[ $FAILED_SUITES -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function with all arguments
main "$@"