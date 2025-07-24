# Test Instructions for GitHub Issues #4, #5, and #6

These instructions will help you verify that the reported issues have been fixed in version 2.0.2.

## Prerequisites

1. Have at least one AppImage file for testing (you can download any AppImage)
2. Access to a terminal
3. The ability to run the old version first, then the updated version

## Test Case 1: Issue #4 - AppImage Name Extraction and Customization

### Problem Description
The `clean_appimage_name()` function didn't properly extract clean names from complex AppImage filenames like `MediaElch_linux_2.12.0_2024-10-13_git-8032465-1.AppImage`.

### Test Setup
Download or create an AppImage with a complex name:
```bash
# Example: Download MediaElch (or rename any AppImage file)
wget https://github.com/Komet/MediaElch/releases/download/v2.12.0/MediaElch_linux_2.12.0_2024-10-13_git-8032465-1.AppImage
# OR rename any existing AppImage:
cp your-app.AppImage MediaElch_linux_2.12.0_2024-10-13_git-8032465-1.AppImage
```

### Test Steps

#### With OLD Version:
1. Run: `ai install MediaElch_linux_2.12.0_2024-10-13_git-8032465-1.AppImage`
2. Check what name is extracted and used
3. Run: `ai list` and observe the displayed name
4. Try: `ai remove MediaElch` and see if it finds the app

#### With NEW Version:
1. Run: `ai install MediaElch_linux_2.12.0_2024-10-13_git-8032465-1.AppImage`
2. **Expected**: You should see a prompt: `Use the name [MediaElch]? (y/n):`
3. Test Option A: Press `y` to accept the extracted name
4. Test Option B: Press `n` and enter a custom name like "My Media Center"
5. Run: `ai list` and verify the name appears correctly
6. Run: `ai remove MediaElch` (or your custom name) and verify it works

### Expected Results
- **OLD**: Name extraction may be poor, no user confirmation
- **NEW**: Clean name extraction with user confirmation option

---

## Test Case 2: Issue #5 - Current Directory Bug

### Problem Description
When choosing to keep an AppImage in the current location (option 0), the tool would fail because `dirname` returns "." for filenames without paths.

### Test Setup
```bash
# Create a test directory and place an AppImage there
mkdir /tmp/appimage_test
cd /tmp/appimage_test
# Copy or download an AppImage to this directory
cp /path/to/your/app.AppImage ./LosslessCut-linux-x86_64.AppImage
```

### Test Steps

#### With OLD Version:
1. Ensure you're in the directory with the AppImage: `cd /tmp/appimage_test`
2. Run: `ai install LosslessCut-linux-x86_64.AppImage`
3. When prompted for storage location, choose option `0` (Keep in current location)
4. **Expected Problem**: The integration should fail or produce incorrect paths

#### With NEW Version:
1. Ensure you're in the directory with the AppImage: `cd /tmp/appimage_test`
2. Run: `ai install LosslessCut-linux-x86_64.AppImage`
3. When prompted for storage location, choose option `0` (Keep in current location)
4. **Expected**: Should work correctly and show the full path instead of "."

### Expected Results
- **OLD**: Error or incorrect path handling when keeping in current location
- **NEW**: Correct path resolution using $PWD

### Verification
After installation, check the desktop file:
```bash
# Find the desktop file
find ~/.local/share/applications -name "*LosslessCut*" -exec cat {} \;
```
Look for the `Exec=` line and verify it contains the full path, not just the filename.

---

## Test Case 3: Issue #6 - Variable Scoping Error

### Problem Description
The remove function had a local variable scoping issue that could cause errors.

### Test Setup
First, install a few AppImages to have something to remove:
```bash
ai install app1.AppImage
ai install app2.AppImage
```

### Test Steps

#### With OLD Version:
1. Run: `ai remove`
2. Check if the command shows available AppImages correctly
3. Run: `ai remove SomeAppName`
4. **Potential Problem**: May encounter variable scoping errors

#### With NEW Version:
1. Run: `ai remove`
2. Should cleanly show available AppImages
3. Run: `ai remove SomeAppName`
4. **Expected**: Should work without variable scoping issues

### Expected Results
- **OLD**: Potential variable scoping errors or inconsistent behavior
- **NEW**: Clean, consistent behavior in remove function

---

## Integration Test: Complete Workflow

### Test the Complete Flow

1. **Install with complex name**:
   ```bash
   ai install MediaElch_linux_2.12.0_2024-10-13_git-8032465-1.AppImage
   ```
   - Verify name customization prompt appears
   - Choose a custom name like "Media Center"

2. **List integrated apps**:
   ```bash
   ai list
   ```
   - Verify your custom name appears in the list
   - Note the location path is correct

3. **Remove using custom name**:
   ```bash
   ai remove Media
   ```
   - Should find and remove the app using the custom name

4. **Test current directory installation**:
   ```bash
   cd /tmp/test_dir
   ai install ./some-app.AppImage
   ```
   - Choose option 0 (keep in current location)
   - Verify it works correctly

## Quick Verification Commands

After testing, you can run these commands to verify everything works:

```bash
# Check script syntax
bash -n install_appimages.sh

# Verify version
grep "CURRENT_VERSION=" install_appimages.sh

# Check that fixes are implemented
grep -n "read -p.*Use the name" install_appimages.sh
grep -n "original_path=\$PWD" install_appimages.sh
grep -n "local name=" install_appimages.sh
```

## Expected Behavior Summary

### Issue #4 (Name Extraction)
- **OLD**: `MediaElch_linux_2.12.0_2024-10-13_git-8032465-1.AppImage` → `MediaElch_2024-10-13_git-8032465-1`
- **NEW**: `MediaElch_linux_2.12.0_2024-10-13_git-8032465-1.AppImage` → `MediaElch` (with confirmation prompt)

### Issue #5 (Current Directory)
- **OLD**: Choosing "Keep in current location" fails or shows incorrect path
- **NEW**: Works correctly and shows full path like `/tmp/appimage_test`

### Issue #6 (Variable Scoping)
- **OLD**: Potential errors in remove function due to variable scoping
- **NEW**: Clean, consistent behavior

## Troubleshooting

If you encounter issues during testing:

1. **Check logs**: `ai logs <appname>` (if available)
2. **Verify installation**: `ai status`
3. **Check desktop files**: `ls ~/.local/share/applications/*.desktop`
4. **Test syntax**: `bash -n install_appimages.sh`

## Cleanup After Testing

```bash
# Remove test AppImages
ai remove MediaElch
ai remove LosslessCut
# Or remove all test desktop files
rm ~/.local/share/applications/*MediaElch*.desktop
rm ~/.local/share/applications/*LosslessCut*.desktop
# Clean up test directory
rm -rf /tmp/appimage_test
```

---

**Note**: Make sure to test each issue separately and compare the behavior between old and new versions to clearly see the improvements!