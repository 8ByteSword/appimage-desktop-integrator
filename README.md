# AppImage Desktop Integrator

Seamlessly integrate AppImages into your Linux desktop with automatic desktop entries, icon extraction, and management commands.

## Features

- **Simple Command**: Use `ai` for all operations
- **Auto-Discovery**: Finds AppImages in common locations (Downloads, Desktop, etc.)
- **Backwards Compatible**: Works with existing AppImage desktop entries
- **Smart Integration**: Auto-detects Electron apps needing `--no-sandbox`
- **Easy Management**: List, remove, update, and debug AppImages
- **Multiple Directories**: Monitor multiple AppImage locations
- **Tab Completion**: Full bash completion support
- **Logging System**: Automatically captures and stores AppImage output
- **Case-Insensitive**: All commands support case-insensitive AppImage name matching
- **Debug Mode**: Run AppImages with verbose output and debugging tools

## Quick Install

One-line installation from the web:

```bash
# Using wget:
wget -qO- https://raw.githubusercontent.com/8ByteSword/appimage-desktop-integrator/main/setup_appimage_integrator.sh | bash

# Using curl:
curl -sSL https://raw.githubusercontent.com/8ByteSword/appimage-desktop-integrator/main/setup_appimage_integrator.sh | bash
```

Or clone and install manually:

```bash
git clone https://github.com/8ByteSword/appimage-desktop-integrator.git
cd appimage-desktop-integrator
chmod +x setup_appimage_integrator.sh
./setup_appimage_integrator.sh
```

## Usage

### Quick Start

```bash
ai              # Show help
ai status       # Show current configuration
ai find         # Find AppImages on your system
ai install      # Interactive installation
ai list         # List all integrated AppImages
```

### Common Tasks

```bash
# Find and integrate AppImages from common locations
ai find

# Install a specific AppImage
ai install ~/Downloads/app.AppImage

# List all integrated AppImages  
ai list

# Remove an AppImage integration
ai remove Firefox

# View stored logs for an app (case-insensitive)
ai logs via

# Run an app with live terminal output
ai run firefox

# Debug an app with verbose output
ai debug firefox

# Show all desktop files
ai desktop
```

### Examples

```bash
# Find all AppImages in Downloads, Desktop, etc.
$ ai find
Found in /home/user/Downloads:
  - Firefox.AppImage
  - VIA.AppImage
Would you like to integrate? (y/n)

# See what's already integrated
$ ai list
1. Firefox
   Version: 120.0
   Location: /home/user/AppImages/Firefox.AppImage
   
2. VIA
   Version: 3.0.0
   Location: /home/user/AppImages/via-3.0.0-linux.AppImage

# Remove an integration
$ ai remove VIA
Found: VIA
Remove this AppImage integration? (y/n): y
✓ Removed VIA integration
```

## What's New in v2.0

- **Automatic Logging**: All AppImages now have their output automatically logged to `~/.config/appimage_desktop_integrator/logs/`
- **Improved `logs` Command**: Shows stored logs instead of launching the app
- **New `run` Command**: Run AppImages with live terminal output (replaces old logs behavior)
- **New `debug` Command**: Run AppImages with verbose output and debugging options
- **Case-Insensitive Search**: Commands like `ai logs firefox` will find "Firefox"
- **Automatic Upgrade**: First run after update will prompt to upgrade existing integrations

## Configuration

The integrator uses a configuration file at `~/.config/appimage_desktop_integrator/config.ini`:

```ini
# Icons location
icons_dir=/home/user/.local/share/icons/appimage-integrator

# Desktop entries location  
update_dir=/home/user/.local/share/applications

# AppImage storage directories (multiple supported)
appimages_dirs=("/home/user/Applications" "/home/user/AppImages")
```

The tool automatically searches these common locations:

- `~/Downloads`
- `~/Desktop`
- `~/Applications`
- `~/apps`
- `~/AppImages`
- `~/.local/bin`
- `/opt`

## Features in Detail

### Auto-Discovery

`ai find` searches common locations for AppImages and shows which ones are already integrated:

```bash
$ ai find
Found in /home/user/Downloads:
  ✓ Firefox.AppImage (already integrated)
  - NewApp.AppImage
```

### Backwards Compatible

Works with AppImages integrated by other tools or manually created desktop entries.

### Smart Electron Detection

Automatically adds `--no-sandbox` flag for Electron-based apps like Discord, Slack, VS Code, etc.

### Interactive Installation

When running `ai install` without arguments, it shows found AppImages and lets you choose where to store them.

### Debug Mode

The integrator provides powerful debugging capabilities:

```bash
# Interactive debug with app-specific flags
ai debug firefox

# Run with debug environment variable
APPIMAGE_DEBUG=1 ai run firefox

# View debug logs after running
ai logs firefox
```

#### Debug Features:

- **App Detection**: Automatically detects app type and applies appropriate debug flags
  - Electron apps: `--verbose --enable-logging --log-level=verbose`
  - Qt apps: Sets `QT_LOGGING_RULES="*=true"`
  - GTK apps: Sets `GTK_DEBUG=all`
- **System Tracing**: Optional `strace` integration for system call analysis
- **Environment Variables**:
  - `APPIMAGE_DEBUG=1` - Enable debug logging in wrapper
  - `APPIMAGE_VERBOSE=1` - Enable verbose output
  - `APPIMAGE_EXTRACT_AND_RUN=1` - Extract and run (for FUSE issues)
- **Enhanced Logging**: Debug mode logs command line arguments, environment variables, and timestamps

## Troubleshooting

### Can't find my AppImages?

- Check `ai status` to see which directories are monitored
- Place AppImages in standard locations like `~/Applications` or `~/Downloads`
- Use `ai install /path/to/app.AppImage` for custom locations

### Desktop entry not appearing?

```bash
update-desktop-database ~/.local/share/applications
```

### App won't launch due to sandbox error?

The tool auto-detects most Electron apps, but if missed:

```bash
# Remove and re-add with force flag
ai remove AppName
ai install /path/to/app.AppImage
```

### Need to debug an AppImage issue?

```bash
# Run with debug output
ai debug AppName

# Check logs for errors
ai logs AppName

# Run with FUSE extraction if mounting fails
APPIMAGE_EXTRACT_AND_RUN=1 ai run AppName
```

## Uninstall

Remove a specific AppImage integration:

```bash
ai remove AppName
```

Completely uninstall the integrator:

```bash
setup_appimage_integrator --purge
```

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## License

This project is released under the [MIT License](https://opensource.org/licenses/MIT).
