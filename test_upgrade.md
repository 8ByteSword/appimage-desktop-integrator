# Testing the v1.x to v2.0 Upgrade

## Current State

- System has old v1.x install_appimages script in /usr/local/bin
- Desktop files are in v1.x format (direct AppImage execution)
- No logging system exists
- Version file shows 1.2.0

## Test Steps

### 1. Verify Current State

```bash
# Check installed version (should not have CURRENT_VERSION variable)
grep "CURRENT_VERSION" /usr/local/bin/install_appimages || echo "v1.x confirmed"

# Check version file
cat ~/.config/appimage_desktop_integrator/VERSION  # Should show 1.2.0

# Check desktop file format (should NOT have wrapper)
grep "Exec=" ~/.local/share/applications/via-3.0.0-linux.desktop
# Should show: Exec="/home/mario/AppImages/via-3.0.0-linux.AppImage" --no-sandbox
```

### 2. Run Setup to Upgrade

```bash
cd ~/projects/8ByteSword/appimage-desktop-integrator
./setup_appimage_integrator.sh
```

This will:

- Download/copy the new v2.0 scripts
- Install them to /usr/local/bin
- Update VERSION file

### 3. Test the Upgrade Prompt

```bash
# Run any ai command to trigger upgrade
ai list
```

You should see:

- "Major version upgrade available!"
- Prompt to upgrade existing installations
- Type 'y' to accept

### 4. Verify Upgrade Results

```bash
# Check wrapper was created
ls -la ~/.config/appimage_desktop_integrator/bin/appimage-run-wrapper.sh

# Check desktop files were updated
grep "Exec=" ~/.local/share/applications/via-3.0.0-linux.desktop
# Should now show wrapper in path

# Test logging
ai run via  # Run briefly then Ctrl+C
ai logs via # Should show the logs

# Verify case-insensitive search
ai logs VIA  # Should also work
```

## What the Upgrade Does

1. **Creates logging infrastructure**:
   - `~/.config/appimage_desktop_integrator/bin/appimage-run-wrapper.sh`
   - `~/.config/appimage_desktop_integrator/logs/` directory

2. **Updates all desktop entries**:
   - Changes Exec line to use wrapper
   - Preserves --no-sandbox flags
   - Adds "Upgraded to v2" comment

3. **Enables new features**:
   - `ai logs <name>` - View stored logs
   - `ai run <name>` - Run with live output
   - Case-insensitive name matching

## Rollback (if needed)

```bash
# Purge and reinstall v1.x
setup_appimage_integrator --purge
# Then reinstall from v1.x branch/tag
```
