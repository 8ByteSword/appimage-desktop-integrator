#!/bin/bash
# Version Bump Script for AppImage Desktop Integrator
# Automates version management across all project files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="$PROJECT_ROOT/VERSION"
MAIN_SCRIPT="$PROJECT_ROOT/install_appimages.sh"

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
Usage: $0 <major|minor|patch> [--dry-run]

Automatically bump version across all project files.

Arguments:
  major     Increment major version (x.0.0)
  minor     Increment minor version (x.y.0)
  patch     Increment patch version (x.y.z)

Options:
  --dry-run Show what would be updated without making changes

Examples:
  $0 patch              # 2.0.2 → 2.0.3
  $0 minor              # 2.0.2 → 2.1.0
  $0 major              # 2.0.2 → 3.0.0
  $0 patch --dry-run    # Show changes without applying

EOF
}

# Validate semantic version format
validate_version() {
    local version="$1"
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version format: $version (expected: X.Y.Z)"
        return 1
    fi
}

# Get current version from VERSION file
get_current_version() {
    if [[ ! -f "$VERSION_FILE" ]]; then
        log_error "VERSION file not found: $VERSION_FILE"
        exit 1
    fi

    local version
    version=$(cat "$VERSION_FILE" | tr -d '[:space:]')

    if [[ -z "$version" ]]; then
        log_error "VERSION file is empty"
        exit 1
    fi

    validate_version "$version"
    echo "$version"
}

# Calculate new version based on bump type
calculate_new_version() {
    local current="$1"
    local bump_type="$2"

    # Split version into components
    local major minor patch
    IFS='.' read -r major minor patch <<< "$current"

    case "$bump_type" in
        major)
            echo "$((major + 1)).0.0"
            ;;
        minor)
            echo "${major}.$((minor + 1)).0"
            ;;
        patch)
            echo "${major}.${minor}.$((patch + 1))"
            ;;
        *)
            log_error "Invalid bump type: $bump_type"
            exit 1
            ;;
    esac
}

# Find all files that need version updates
find_version_references() {
    local current_version="$1"
    local files=()

    log_info "Scanning for version references..." >&2

    # Main script CURRENT_VERSION variable
    if grep -q "CURRENT_VERSION=" "$MAIN_SCRIPT"; then
        files+=("$MAIN_SCRIPT")
    fi

    # Test files with hardcoded versions
    while IFS= read -r -d '' file; do
        if grep -q "$current_version" "$file"; then
            files+=("$file")
        fi
    done < <(find "$PROJECT_ROOT/tests" -name "*.sh" -print0 2>/dev/null || true)

    # Other script files
    while IFS= read -r -d '' file; do
        if [[ "$file" != "$MAIN_SCRIPT" ]] && grep -q "$current_version" "$file"; then
            files+=("$file")
        fi
    done < <(find "$PROJECT_ROOT" -name "*.sh" -not -path "*/tests/*" -not -path "*/scripts/*" -print0 2>/dev/null || true)

    # Remove duplicates and sort
    printf '%s\n' "${files[@]}" | sort -u
}

# Update version in a file
update_file_version() {
    local file="$1"
    local old_version="$2"
    local new_version="$3"
    local dry_run="$4"

    if [[ ! -f "$file" ]]; then
        log_warning "File not found: $file"
        return 1
    fi

    # Count occurrences to report
    local count
    count=$(grep -c "$old_version" "$file" 2>/dev/null | head -1 || echo "0")
    count=$(echo "$count" | tr -d '[:space:]')

    if [[ "$count" -eq 0 ]]; then
        return 0
    fi

    log_info "  $file ($count occurrence$([ "$count" -gt 1 ] && echo "s" || echo ""))"

    if [[ "$dry_run" == "false" ]]; then
        # Create backup
        cp "$file" "$file.backup"

        # Update version occurrences
        sed -i "s/$old_version/$new_version/g" "$file"

        # Verify the update worked
        local new_count
        new_count=$(grep -c "$new_version" "$file" 2>/dev/null | head -1 || echo "0")
        new_count=$(echo "$new_count" | tr -d '[:space:]')

        if [[ "$new_count" -ne "$count" ]]; then
            log_error "Version update failed in $file"
            mv "$file.backup" "$file"  # Restore backup
            return 1
        fi

        rm "$file.backup"  # Remove backup on success
    else
        # Show what would change in dry-run mode
        grep -n "$old_version" "$file" | head -3 | while read -r line; do
            echo "    $line"
        done
        if [[ "$count" -gt 3 ]]; then
            echo "    ... and $((count - 3)) more"
        fi
    fi

    return 0
}

# Main version bump logic
bump_version() {
    local bump_type="$1"
    local dry_run="${2:-false}"

    log_info "Starting version bump process..."

    # Get current version
    local current_version
    current_version=$(get_current_version)
    log_info "Current version: $current_version"

    # Calculate new version
    local new_version
    new_version=$(calculate_new_version "$current_version" "$bump_type")
    log_info "New version: $new_version"

    if [[ "$dry_run" == "true" ]]; then
        log_warning "DRY RUN MODE - No files will be modified"
        echo
    fi

    # Update VERSION file
    log_info "Updating VERSION file..."
    if [[ "$dry_run" == "false" ]]; then
        echo "$new_version" > "$VERSION_FILE"
        log_success "  $VERSION_FILE"
    else
        log_info "  Would write '$new_version' to $VERSION_FILE"
    fi

    # Find and update all files with version references
    log_info "Updating version references in project files..."
    local files
    readarray -t files < <(find_version_references "$current_version")

    local update_count=0
    local failed_count=0

    for file in "${files[@]}"; do
        if update_file_version "$file" "$current_version" "$new_version" "$dry_run"; then
            ((update_count++))
        else
            ((failed_count++))
        fi
    done

    echo
    if [[ "$dry_run" == "true" ]]; then
        log_info "Summary (dry run):"
        log_info "  Would update VERSION file: $current_version → $new_version"
        log_info "  Would update $update_count file(s) with version references"
    else
        log_success "Version bump completed successfully!"
        log_success "  Updated VERSION file: $current_version → $new_version"
        log_success "  Updated $update_count file(s) with version references"

        if [[ "$failed_count" -gt 0 ]]; then
            log_warning "  Failed to update $failed_count file(s)"
        fi

        echo
        log_info "Next steps:"
        log_info "  1. Review the changes: git diff"
        log_info "  2. Test the build: ./tests/run_tests.sh"
        log_info "  3. Commit changes: git add . && git commit -m \"bump: version $new_version\""
        log_info "  4. Create release tag: git tag v$new_version"
    fi
}

# Argument parsing
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    local bump_type=""
    local dry_run="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            major|minor|patch)
                if [[ -n "$bump_type" ]]; then
                    log_error "Multiple bump types specified"
                    exit 1
                fi
                bump_type="$1"
                ;;
            --dry-run)
                dry_run="true"
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

    if [[ -z "$bump_type" ]]; then
        log_error "Bump type required (major|minor|patch)"
        usage
        exit 1
    fi

    # Ensure we're in the right directory
    if [[ ! -f "$VERSION_FILE" ]]; then
        log_error "Must be run from project root (VERSION file not found)"
        exit 1
    fi

    bump_version "$bump_type" "$dry_run"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi