# Version Management Scripts

Automated version management system for AppImage Desktop Integrator.

## Overview

This directory contains scripts that automate the version management workflow, eliminating the need for manual version updates across multiple files.

## Single Source of Truth

The project now uses the `VERSION` file as the authoritative source of version information:

- **VERSION file** - Contains the current version (e.g., `2.0.2`)
- **Main script** - Dynamically reads from VERSION file using `get_current_version()` function
- **Test framework** - Uses `get_project_version()` to get current version for tests

## Scripts

### `bump-version.sh`

Main version management tool that updates versions across all project files.

```bash
# Patch release (2.0.2 → 2.0.3)
./scripts/bump-version.sh patch

# Minor release (2.0.2 → 2.1.0)
./scripts/bump-version.sh minor

# Major release (2.0.2 → 3.0.0)
./scripts/bump-version.sh major

# Preview changes without applying them
./scripts/bump-version.sh patch --dry-run
```

**What it updates:**
- VERSION file (authoritative source)
- Main script version references
- Test files with hardcoded version expectations
- Any other scripts that reference the current version

### `validate-version.sh`

Validates version consistency across the project.

```bash
# Quick consistency check
./scripts/validate-version.sh

# Detailed validation with verbose output
./scripts/validate-version.sh --verbose

# Automatically fix minor issues
./scripts/validate-version.sh --fix
```

**Checks performed:**
- VERSION file vs main script consistency
- Changelog version alignment
- Test file version expectations
- Script file version references

### `release.sh`

Complete release workflow with validation, testing, and git operations.

```bash
# Standard patch release
./scripts/release.sh patch

# Preview release without making changes
./scripts/release.sh minor --dry-run

# Release without running tests (not recommended)
./scripts/release.sh patch --skip-tests

# Release without git operations
./scripts/release.sh minor --skip-git
```

**Release workflow:**
1. Validate current state and version consistency
2. Run test suite to ensure quality
3. Bump version across all files
4. Update changelog entry (if needed)
5. Git commit, tag, and push
6. Display release summary

## Before This System

Previously, releasing a new version required manually updating:

- `CURRENT_VERSION="2.0.2"` in `install_appimages.sh`
- `VERSION` file for distribution
- Multiple test files with hardcoded version expectations
- Documentation consistency checks

## After This System

Now, to release a new version:

```bash
# Single command for everything
./scripts/release.sh patch
```

This automatically:
- ✅ Updates VERSION file (single source of truth)
- ✅ Propagates version to all dependent files
- ✅ Runs tests to ensure quality
- ✅ Creates git commit and tag
- ✅ Updates changelog
- ✅ Validates consistency

## Version Format

All versions follow [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (e.g., `2.0.2`)
- **Major**: Breaking changes
- **Minor**: New features, backward compatible
- **Patch**: Bug fixes, backward compatible

## Integration

The main script now reads the version dynamically:

```bash
# Old hardcoded approach
CURRENT_VERSION="2.0.2"

# New dynamic approach
get_current_version() {
    local version_file="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/VERSION"
    if [[ -f "$version_file" ]]; then
        cat "$version_file" | tr -d '[:space:]'
    else
        echo "0.0.0"
    fi
}

CURRENT_VERSION=$(get_current_version)
```

Test framework uses similar logic:

```bash
get_project_version() {
    local version_file="$TEST_FRAMEWORK_DIR/../VERSION"
    if [[ -f "$version_file" ]]; then
        cat "$version_file" | tr -d '[:space:]'
    else
        echo "0.0.0"
    fi
}
```

## Troubleshooting

### Version Validation Warnings

The validation script may show warnings about "inconsistent versions" in test files. Many of these are actually:

- **AppImage version numbers** in test data (e.g., `VSCode-1.85.0.AppImage`)
- **Example version strings** used for testing (e.g., version parsing tests)
- **Historical version references** in documentation

These are **not errors** - they're legitimate test data that should remain unchanged.

### Core Version Consistency

The important consistency checks are:

- ✅ VERSION file matches main script's `get_current_version()` output
- ✅ Main script uses `CURRENT_VERSION=$(get_current_version)`
- ✅ Test framework uses `get_project_version()` for dynamic versioning

### Manual Override

If needed, you can still manually set versions:

```bash
# Set specific version
echo "3.0.0" > VERSION

# Validate consistency
./scripts/validate-version.sh --fix
```

## Benefits

- **One-command releases** - No more manual file updates
- **Consistency guaranteed** - Automated updates prevent version mismatches
- **Test reliability** - Tests always use current version
- **Maintainer friendly** - Clear workflow for version management
- **Error prevention** - Validation catches inconsistencies before release