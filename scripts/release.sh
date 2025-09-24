#!/bin/bash
# Release Workflow Script for AppImage Desktop Integrator
# Complete release workflow with validation, testing, and git operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="$PROJECT_ROOT/VERSION"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }
log_step() { echo -e "\n${CYAN}▶${NC} $*"; }

# Usage information
usage() {
    cat <<EOF
Usage: $0 <major|minor|patch> [options]

Complete release workflow for AppImage Desktop Integrator.

Arguments:
  major     Release major version (X.0.0) - breaking changes
  minor     Release minor version (X.Y.0) - new features
  patch     Release patch version (X.Y.Z) - bug fixes

Options:
  --dry-run     Show what would happen without making changes
  --skip-tests  Skip test suite execution (not recommended)
  --skip-git    Skip git operations (commit, tag, push)
  --force       Force release even if validation fails

Examples:
  $0 patch                    # Standard patch release
  $0 minor --dry-run          # Preview minor release
  $0 major --skip-tests       # Major release without tests

Release Process:
  1. Validate current state and version consistency
  2. Run test suite to ensure quality
  3. Bump version across all files
  4. Update changelog entry (if needed)
  5. Git commit, tag, and push
  6. Display release summary

EOF
}

# Check if git working directory is clean
check_git_status() {
    if ! git diff --quiet HEAD; then
        log_error "Working directory has uncommitted changes"
        log_info "Commit or stash changes before releasing"
        return 1
    fi

    if ! git diff --cached --quiet; then
        log_error "Staging area has uncommitted changes"
        log_info "Commit staged changes before releasing"
        return 1
    fi

    # Check if we're on main branch
    local current_branch
    current_branch=$(git branch --show-current)
    if [[ "$current_branch" != "main" ]]; then
        log_warning "Not on 'main' branch (currently on '$current_branch')"
        log_warning "Releases are typically made from 'main' branch"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi

    return 0
}

# Run test suite
run_tests() {
    log_step "Running test suite..."

    local test_script="$PROJECT_ROOT/tests/run_tests.sh"
    if [[ -f "$test_script" ]]; then
        log_info "Executing: $test_script"
        if "$test_script"; then
            log_success "All tests passed"
        else
            log_error "Test suite failed"
            return 1
        fi
    else
        # Try alternative test patterns
        if [[ -f "$PROJECT_ROOT/tests/test_framework.sh" ]]; then
            log_info "Running individual test files..."
            local failed_tests=0
            local total_tests=0

            for test_file in "$PROJECT_ROOT/tests"/test_*.sh; do
                if [[ -f "$test_file" ]]; then
                    ((total_tests++))
                    log_info "Running $(basename "$test_file")..."
                    if ! "$test_file"; then
                        ((failed_tests++))
                        log_error "$(basename "$test_file") failed"
                    fi
                fi
            done

            if [[ $failed_tests -gt 0 ]]; then
                log_error "$failed_tests out of $total_tests test files failed"
                return 1
            else
                log_success "All $total_tests test files passed"
            fi
        else
            log_warning "No test suite found"
            log_warning "Consider adding tests before release"
        fi
    fi

    return 0
}

# Get current version
get_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE" | tr -d '[:space:]'
    else
        echo "0.0.0"
    fi
}

# Update changelog if needed
update_changelog() {
    local new_version="$1"
    local dry_run="$2"

    local changelog="$PROJECT_ROOT/CHANGELOG.md"
    if [[ ! -f "$changelog" ]]; then
        log_warning "CHANGELOG.md not found - skipping changelog update"
        return 0
    fi

    # Check if version already exists in changelog
    if grep -q "## \[$new_version\]" "$changelog"; then
        log_info "Changelog already contains entry for version $new_version"
        return 0
    fi

    log_step "Updating changelog..."

    if [[ "$dry_run" == "false" ]]; then
        # Get current date
        local release_date
        release_date=$(date "+%Y-%m-%d")

        # Create temporary changelog entry
        local temp_entry="/tmp/changelog_entry.md"
        cat > "$temp_entry" <<EOF

## [$new_version] - $release_date

### Added
- Version $new_version release

### Changed
- Updated version references across project files

### Fixed
- Version consistency across all components

EOF

        # Insert new entry after the first line (usually the header)
        sed -i "1r $temp_entry" "$changelog"
        rm "$temp_entry"

        log_success "Changelog updated with version $new_version"
    else
        log_info "Would add changelog entry for version $new_version"
    fi

    return 0
}

# Commit and tag release
git_release() {
    local new_version="$1"
    local dry_run="$2"

    log_step "Creating git release..."

    if [[ "$dry_run" == "false" ]]; then
        # Add all changes
        git add .

        # Commit with version message
        git commit -m "release: version $new_version

- Automated version bump to $new_version
- Updated all version references
- Updated changelog entry

Generated by release automation script"

        # Create annotated tag
        git tag -a "v$new_version" -m "Release version $new_version"

        log_success "Created commit and tag for version $new_version"

        # Ask about pushing
        read -p "Push commit and tag to origin? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            git push origin HEAD
            git push origin "v$new_version"
            log_success "Pushed commit and tag to origin"
        else
            log_info "Local changes ready - push manually when ready:"
            log_info "  git push origin HEAD"
            log_info "  git push origin v$new_version"
        fi
    else
        log_info "Would create commit with message: 'release: version $new_version'"
        log_info "Would create tag: v$new_version"
        log_info "Would push to origin"
    fi

    return 0
}

# Main release workflow
release() {
    local bump_type="$1"
    local dry_run="${2:-false}"
    local skip_tests="${3:-false}"
    local skip_git="${4:-false}"
    local force="${5:-false}"

    log_info "Starting release workflow..."
    log_info "Release type: $bump_type"

    if [[ "$dry_run" == "true" ]]; then
        log_warning "DRY RUN MODE - No changes will be made"
        echo
    fi

    # Get current version
    local current_version
    current_version=$(get_current_version)
    log_info "Current version: $current_version"

    # Step 1: Validate version consistency
    log_step "Step 1: Validating version consistency..."
    if "$SCRIPT_DIR/validate-version.sh" --verbose; then
        log_success "Version validation passed"
    else
        log_error "Version validation failed"
        if [[ "$force" == "false" ]]; then
            log_info "Use --force to continue anyway, or run:"
            log_info "  ./scripts/validate-version.sh --fix"
            return 1
        else
            log_warning "Continuing despite validation errors (--force specified)"
        fi
    fi

    # Step 2: Check git status
    if [[ "$skip_git" == "false" ]]; then
        log_step "Step 2: Checking git status..."
        if [[ "$dry_run" == "false" ]] && ! check_git_status; then
            if [[ "$force" == "false" ]]; then
                return 1
            else
                log_warning "Continuing despite git issues (--force specified)"
            fi
        else
            log_success "Git working directory is clean"
        fi
    else
        log_step "Step 2: Skipping git status check (--skip-git)"
    fi

    # Step 3: Run tests
    if [[ "$skip_tests" == "false" ]]; then
        log_step "Step 3: Running test suite..."
        if [[ "$dry_run" == "false" ]] && ! run_tests; then
            if [[ "$force" == "false" ]]; then
                log_error "Tests failed - aborting release"
                return 1
            else
                log_warning "Continuing despite test failures (--force specified)"
            fi
        else
            log_success "Test suite validation passed"
        fi
    else
        log_step "Step 3: Skipping test suite (--skip-tests)"
    fi

    # Step 4: Bump version
    log_step "Step 4: Bumping version..."
    if [[ "$dry_run" == "true" ]]; then
        "$SCRIPT_DIR/bump-version.sh" "$bump_type" --dry-run
    else
        "$SCRIPT_DIR/bump-version.sh" "$bump_type"
    fi

    local new_version
    if [[ "$dry_run" == "false" ]]; then
        new_version=$(get_current_version)
    else
        # Calculate what the new version would be for dry run
        case "$bump_type" in
            major) new_version=$(echo "$current_version" | awk -F. '{print ($1+1)".0.0"}') ;;
            minor) new_version=$(echo "$current_version" | awk -F. '{print $1"."($2+1)".0"}') ;;
            patch) new_version=$(echo "$current_version" | awk -F. '{print $1"."$2"."($3+1)}') ;;
        esac
    fi

    # Step 5: Update changelog
    log_step "Step 5: Updating changelog..."
    update_changelog "$new_version" "$dry_run"

    # Step 6: Git operations
    if [[ "$skip_git" == "false" ]]; then
        log_step "Step 6: Git commit and tag..."
        git_release "$new_version" "$dry_run"
    else
        log_step "Step 6: Skipping git operations (--skip-git)"
    fi

    # Step 7: Release summary
    log_step "Release Summary"
    echo
    log_success "Release workflow completed successfully!"
    log_info "Version: $current_version → $new_version"
    log_info "Type: $bump_type release"

    if [[ "$dry_run" == "false" ]]; then
        log_info "Changes made:"
        log_info "  ✓ Version bumped in all project files"
        log_info "  ✓ Changelog updated (if applicable)"
        if [[ "$skip_git" == "false" ]]; then
            log_info "  ✓ Git commit and tag created"
        fi
        echo
        log_info "Next steps:"
        log_info "  • Verify the release: git log -1"
        log_info "  • Check the tag: git tag -l v$new_version"
        if [[ "$skip_git" == "false" ]]; then
            log_info "  • Monitor CI/CD pipeline if applicable"
        fi
    else
        echo
        log_info "This was a dry run - no actual changes made"
        log_info "Remove --dry-run to execute the release"
    fi

    return 0
}

# Main function
main() {
    local bump_type=""
    local dry_run="false"
    local skip_tests="false"
    local skip_git="false"
    local force="false"

    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

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
            --skip-tests)
                skip_tests="true"
                ;;
            --skip-git)
                skip_git="true"
                ;;
            --force)
                force="true"
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

    # Check if required scripts exist
    if [[ ! -x "$SCRIPT_DIR/bump-version.sh" ]]; then
        log_error "bump-version.sh script not found or not executable"
        exit 1
    fi

    if [[ ! -x "$SCRIPT_DIR/validate-version.sh" ]]; then
        log_error "validate-version.sh script not found or not executable"
        exit 1
    fi

    release "$bump_type" "$dry_run" "$skip_tests" "$skip_git" "$force"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi