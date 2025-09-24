#!/bin/bash
# Version Validation Script for AppImage Desktop Integrator
# Validates version consistency across all project files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="$PROJECT_ROOT/VERSION"
MAIN_SCRIPT="$PROJECT_ROOT/install_appimages.sh"
CHANGELOG="$PROJECT_ROOT/CHANGELOG.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }

# Usage information
usage() {
    cat <<EOF
Usage: $0 [--verbose] [--fix]

Validates version consistency across all project files.

Options:
  --verbose    Show detailed information about version checks
  --fix        Automatically fix minor inconsistencies where possible

Exit codes:
  0    All versions are consistent
  1    Version inconsistencies found
  2    Critical version validation errors

EOF
}

# Validate semantic version format
validate_version_format() {
    local version="$1"
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 1
    fi
    return 0
}

# Get version from VERSION file
get_file_version() {
    if [[ ! -f "$VERSION_FILE" ]]; then
        log_error "VERSION file not found: $VERSION_FILE"
        exit 2
    fi

    local version
    version=$(cat "$VERSION_FILE" | tr -d '[:space:]')

    if [[ -z "$version" ]]; then
        log_error "VERSION file is empty"
        exit 2
    fi

    if ! validate_version_format "$version"; then
        log_error "Invalid version format in VERSION file: $version (expected: X.Y.Z)"
        exit 2
    fi

    echo "$version"
}

# Get version from main script (by reading VERSION file that script now uses)
get_script_version() {
    if [[ ! -f "$MAIN_SCRIPT" ]]; then
        log_error "Main script not found: $MAIN_SCRIPT"
        exit 2
    fi

    # Since the script now reads from VERSION file, just verify it uses get_current_version()
    if ! grep -q "CURRENT_VERSION=\$(get_current_version)" "$MAIN_SCRIPT"; then
        log_error "Main script does not use get_current_version() function"
        exit 2
    fi

    # Use the same logic as the script does
    local script_dir version_file version
    script_dir=$(dirname "$MAIN_SCRIPT")
    version_file="$script_dir/VERSION"
    
    if [[ -f "$version_file" ]]; then
        version=$(cat "$version_file" | tr -d '[:space:]')
    else
        version="0.0.0"
    fi

    if [[ -z "$version" ]]; then
        log_error "Unable to get version from script's VERSION file"
        exit 2
    fi

    if ! validate_version_format "$version"; then
        log_error "Invalid version format in main script: $version (expected: X.Y.Z)"
        exit 2
    fi

    echo "$version"
}

# Get version from changelog
get_changelog_version() {
    if [[ ! -f "$CHANGELOG" ]]; then
        log_warning "CHANGELOG.md not found"
        return 1
    fi

    local version
    version=$(grep "^## \[" "$CHANGELOG" | head -1 | grep -o "\[.*\]" | tr -d "[]" || echo "")

    if [[ -z "$version" ]]; then
        log_warning "No version found in changelog"
        return 1
    fi

    if ! validate_version_format "$version"; then
        log_warning "Invalid version format in changelog: $version"
        return 1
    fi

    echo "$version"
}

# Find inconsistent version references in test files
check_test_version_consistency() {
    local expected_version="$1"
    local verbose="$2"
    local inconsistencies=0

    if [[ "$verbose" == "true" ]]; then
        log_info "Checking test files for version consistency..."
    fi

    # Check test files
    while IFS= read -r -d '' file; do
        local inconsistent_versions
        inconsistent_versions=$(grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' "$file" 2>/dev/null | sort -u | grep -v "^$expected_version$" || true)

        if [[ -n "$inconsistent_versions" ]]; then
            log_warning "Inconsistent versions in $file:"
            while IFS= read -r version; do
                if [[ -n "$version" ]]; then
                    local count
                    count=$(grep -c "$version" "$file")
                    log_warning "  $version ($count occurrence$([ "$count" -gt 1 ] && echo "s" || echo ""))"
                    ((inconsistencies++))
                fi
            done <<< "$inconsistent_versions"
        elif [[ "$verbose" == "true" ]]; then
            log_success "  $(basename "$file") - consistent"
        fi
    done < <(find "$PROJECT_ROOT/tests" -name "*.sh" -print0 2>/dev/null || true)

    return $inconsistencies
}

# Check for version references in other script files
check_script_version_consistency() {
    local expected_version="$1"
    local verbose="$2"
    local inconsistencies=0

    if [[ "$verbose" == "true" ]]; then
        log_info "Checking script files for version consistency..."
    fi

    while IFS= read -r -d '' file; do
        if [[ "$file" == "$MAIN_SCRIPT" ]]; then
            continue  # Skip main script, already checked
        fi

        local inconsistent_versions
        inconsistent_versions=$(grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' "$file" 2>/dev/null | sort -u | grep -v "^$expected_version$" || true)

        if [[ -n "$inconsistent_versions" ]]; then
            log_warning "Inconsistent versions in $file:"
            while IFS= read -r version; do
                if [[ -n "$version" ]]; then
                    local count
                    count=$(grep -c "$version" "$file")
                    log_warning "  $version ($count occurrence$([ "$count" -gt 1 ] && echo "s" || echo ""))"
                    ((inconsistencies++))
                fi
            done <<< "$inconsistent_versions"
        elif [[ "$verbose" == "true" ]]; then
            log_success "  $(basename "$file") - consistent"
        fi
    done < <(find "$PROJECT_ROOT" -name "*.sh" -not -path "*/tests/*" -not -path "*/scripts/*" -print0 2>/dev/null || true)

    return $inconsistencies
}

# Fix VERSION file to match main script
fix_version_file() {
    local script_version="$1"
    log_info "Fixing VERSION file to match script version: $script_version"
    echo "$script_version" > "$VERSION_FILE"
    log_success "VERSION file updated"
}

# Main validation logic
validate_versions() {
    local verbose="${1:-false}"
    local fix="${2:-false}"
    local exit_code=0

    log_info "Starting version validation..."

    # Get versions from different sources
    local file_version script_version changelog_version
    file_version=$(get_file_version)
    script_version=$(get_script_version)

    if changelog_version=$(get_changelog_version); then
        has_changelog="true"
    else
        has_changelog="false"
        changelog_version=""
    fi

    if [[ "$verbose" == "true" ]]; then
        echo
        log_info "Version information:"
        log_info "  VERSION file: $file_version"
        log_info "  Main script:  $script_version"
        if [[ "$has_changelog" == "true" ]]; then
            log_info "  Changelog:    $changelog_version"
        else
            log_info "  Changelog:    (not found or invalid)"
        fi
        echo
    fi

    # Check VERSION file vs main script consistency
    if [[ "$file_version" != "$script_version" ]]; then
        log_error "Version mismatch between VERSION file ($file_version) and main script ($script_version)"

        if [[ "$fix" == "true" ]]; then
            log_info "Attempting to fix..."
            # Use script version as authoritative source for now
            fix_version_file "$script_version"
            file_version="$script_version"
        else
            exit_code=1
        fi
    else
        log_success "VERSION file and main script versions match: $file_version"
    fi

    # Check changelog consistency
    if [[ "$has_changelog" == "true" ]]; then
        if [[ "$changelog_version" != "$script_version" ]]; then
            log_warning "Changelog version ($changelog_version) differs from current version ($script_version)"
            log_warning "Consider updating the changelog for the current release"
            # This is a warning, not an error - changelog might be ahead or behind
        else
            log_success "Changelog version matches current version: $changelog_version"
        fi
    fi

    # Use script version as the authoritative version for consistency checks
    local authoritative_version="$script_version"

    # Check test file consistency
    if ! check_test_version_consistency "$authoritative_version" "$verbose"; then
        log_error "Test files contain inconsistent version references"
        log_info "Use './scripts/bump-version.sh patch --dry-run' to see what would be updated"
        exit_code=1
    elif [[ "$verbose" == "true" ]]; then
        log_success "All test files have consistent version references"
    fi

    # Check other script file consistency
    if ! check_script_version_consistency "$authoritative_version" "$verbose"; then
        log_error "Script files contain inconsistent version references"
        log_info "Use './scripts/bump-version.sh patch --dry-run' to see what would be updated"
        exit_code=1
    elif [[ "$verbose" == "true" ]]; then
        log_success "All script files have consistent version references"
    fi

    echo
    if [[ $exit_code -eq 0 ]]; then
        log_success "Version validation passed! Current version: $authoritative_version"
        log_info "All project files are consistent with version $authoritative_version"
    else
        log_error "Version validation failed!"
        log_info "Use '--fix' to automatically fix some issues"
        log_info "Use './scripts/bump-version.sh' to update versions consistently"
    fi

    return $exit_code
}

# Main function
main() {
    local verbose="false"
    local fix="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                verbose="true"
                ;;
            --fix)
                fix="true"
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done

    # Ensure we're in the right directory
    if [[ ! -f "$VERSION_FILE" ]]; then
        log_error "Must be run from project root (VERSION file not found)"
        exit 2
    fi

    validate_versions "$verbose" "$fix"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi