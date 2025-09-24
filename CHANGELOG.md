# Changelog

## [2.1.0] - 2025-01-28

### Added

- **Intelligent Remove**: Enhanced `ai remove` command with fuzzy matching, case-insensitive search, and multiple match handling
- **Smart Suggestions**: When no matches found, shows "Did you mean..." suggestions with available AppImages
- **Multiple Match Selection**: When multiple AppImages match, presents numbered list for user selection
- **Embedded Versioning**: Version is now injected during installation for reliable version reporting

### Fixed

- **Critical: Atomic File Operations**: Fixed major bug where AppImages would be moved before processing validation, causing orphaned files when integration failed
- **Config Parsing**: Resolved subshell variable scope issues that prevented custom directory arrays from working properly
- **Process Substitution**: Fixed config parsing to work correctly in all execution contexts (test environments, wrapper scripts)
- **Variable Scoping**: Fixed local variable persistence issues in config parsing functions
- **Version Detection**: Simplified and hardened version detection system

### Changed

- **File Movement Logic**: AppImages are now processed in original location first, then moved only on success
- **Remove Workflow**: Complete overhaul of removal command with intelligent matching algorithms  
- **Version System**: Removed redundant config version files, using single embedded version as source of truth
- **Error Recovery**: Improved error handling with proper cleanup when operations fail

### Technical Improvements

- **Robust Config Processing**: Process substitution eliminates subshell variable persistence issues
- **Conditional Debug Output**: Debug output only when `APPIMAGE_INTEGRATOR_DEBUG=1` is set
- **Better Array Handling**: Fixed xargs mangling of array strings with proper parameter expansion
- **Atomic Desktop Updates**: Desktop file operations are now atomic with proper rollback

## [2.0.2] - 2025-07-24

### Added

- **Interactive Name Customization**: During installation, users can now confirm or customize the extracted AppImage name for better user experience (fixes #4)

### Fixed

- **AppImage Name Extraction**: Improved name extraction from complex AppImage filenames with better handling of version numbers and platform suffixes (fixes #4)
- **Current Directory Handling**: Fixed bug where keeping AppImage in current location would fail due to `dirname` returning "." instead of the actual path (fixes #5)
- **Variable Scoping**: Fixed local variable scoping issue in the remove function that could cause potential conflicts (fixes #6)

### Changed

- **Name Extraction Logic**: Simplified AppImage name cleaning to use alphabetic character extraction with user confirmation
- **Installation Flow**: Installation now prompts for name confirmation, allowing for custom display names while maintaining file system links

## [2.0.1] - 2025-07-03

### Fixed

- **Directory Handling**: Fixed handling of non-existing directories for desktop entries (PR #3)
- **Installation Robustness**: Improved error handling when desktop entry directories don't exist

## [2.0.0] - 2025-06-03

### Added

- **Proper Logging System**: All AppImages now have their output logged to `~/.config/appimage_desktop_integrator/logs/`
- **New `run` Command**: Run AppImages with live terminal output using `ai run <name>`
- **Case-Insensitive Search**: All commands now support case-insensitive matching of AppImage names
- **Automatic Upgrade**: Major version upgrade mechanism that migrates existing installations
- **Logging Wrapper**: Desktop entries use a wrapper script to capture all AppImage output

### Changed

- **BREAKING: `logs` Command**: Now shows stored logs instead of launching the AppImage
- **Desktop Entry Format**: All desktop entries now use the logging wrapper for execution
- **Version Tracking**: Added version file to track installed version

### Fixed

- **Case Sensitivity**: Fixed issue where `ai logs via` couldn't find "Via" AppImage
- **Log Persistence**: AppImage output is now properly captured and stored

### Migration

- Running any command will automatically prompt to upgrade existing installations
- Upgrade adds logging support to all previously integrated AppImages
- Original AppImage functionality is preserved while adding logging

## [1.2.0] - Unreleased (Development Version)

**Note**: This version was used during development but never officially released. Users with this version should upgrade to 2.0.0.

### Added

- **Management Commands**: New commands for list, search, uninstall, and update-all
- **Bash Completion**: Tab completion for commands and AppImage names
- **Force Reinstall**: `-f` flag to force update existing desktop entries
- **Better Electron Detection**: Automatically detects and handles Electron apps
- **Improved Icon Extraction**: Prefers higher resolution icons
- **Clean App Names**: Better parsing of AppImage names for desktop entries
- **One-line Install**: Documented web installation method

### Changed

- **Config Location**: Moved to `~/.config/appimage_desktop_integrator/`
- **Enhanced Sandbox Detection**: More reliable detection of apps needing --no-sandbox
- **Better Error Handling**: Improved mount and unmount procedures

### Fixed

- **Desktop Entry Updates**: Properly updates existing entries
- **Icon Path Handling**: Fixed issues with icon extraction and storage

## [1.1.0] - 2024-10-03

### Added

- **Update Feature**: `install_appimages.sh` now checks for updates from the repository and prompts the user to update.
- **Sandbox Detection**: The script detects if an AppImage requires the `--no-sandbox` option due to sandboxing issues and prompts the user to add it to the desktop entry.
- **Purge Option**: `setup_appimage_integrator.sh` now includes a `--purge` option to uninstall and remove all traces of the integrator.

### Changed

- **Script Names**: Renamed `install.sh` to `setup_appimage_integrator.sh` for clarity.

### Fixed

- **Sandbox Detection Bug**: Fixed an issue where sandboxing problems were not correctly detected.

---

[Full Changelog](https://github.com/8ByteSword/appimage-desktop-integrator/commits/main)
