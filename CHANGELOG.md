# Changelog

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
