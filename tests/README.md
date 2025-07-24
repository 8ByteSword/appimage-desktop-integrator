# AppImage Desktop Integrator - Test Suite

Comprehensive testing framework for the AppImage Desktop Integrator project.

## Overview

This test suite provides isolated testing environments to safely test all functionality without affecting your actual system configuration. Tests run in completely isolated environments with mock files and directories.

## Quick Start

```bash
# Run all tests
./tests/run_tests.sh

# Run specific test suite
./tests/run_tests.sh basic

# Run with verbose output
./tests/run_tests.sh -v

# Run without cleanup (for debugging)
./tests/run_tests.sh --no-cleanup
```

## Test Suites

### 1. Basic Functionality (`test_basic_functionality.sh`)
Tests core commands and basic workflows:
- Status command
- Directory creation
- Find command (empty and with AppImages)
- List command
- Help command
- Configuration file handling
- Version management

### 2. AppImage Processing (`test_appimage_processing.sh`)
Tests AppImage installation and integration:
- Installation workflow
- Desktop file creation
- Electron app detection
- AppImage moving/copying
- Duplicate prevention
- Removal functionality
- Logging system
- Icon extraction

### 3. Edge Cases (`test_edge_cases.sh`)
Tests error handling and edge cases:
- Invalid file paths
- Permission issues
- Corrupted configurations
- Special characters in names
- Long paths
- Symlink handling
- Case-insensitive operations

## Test Framework Features

### Isolated Environment
- Creates temporary test environment in `/tmp/appimage_integrator_tests/`
- Completely isolated from your real configuration
- Mock AppImage files that simulate real AppImages
- Separate HOME, config, and desktop directories

### Mock AppImages
Tests use mock AppImage files that:
- Simulate `--appimage-mount` behavior
- Create mock desktop files and icons
- Handle various app types (Electron, Qt, GTK)
- Don't require actual AppImage binaries

### Comprehensive Assertions
- `assert_equal` - Test value equality
- `assert_file_exists` - Verify files exist
- `assert_file_not_exists` - Verify files don't exist
- `assert_dir_exists` - Verify directories exist
- `assert_command_succeeds` - Test command success
- `assert_command_fails` - Test command failure

## Running Tests

### Test Runner Options

```bash
./tests/run_tests.sh [OPTIONS] [SUITE]

Options:
  -v, --verbose       Enable verbose output
  -n, --no-cleanup    Don't cleanup test environments
  -p, --parallel      Run test suites in parallel
  -h, --help          Show help message

Suites:
  basic              Basic functionality tests
  appimage           AppImage processing tests
  edge               Edge cases and error handling
  all                All test suites (default)
```

### Examples

```bash
# Run all tests with summary output
./tests/run_tests.sh

# Run only basic tests with verbose output
./tests/run_tests.sh -v basic

# Run edge case tests and preserve environment for debugging
./tests/run_tests.sh -n edge

# Run all tests in parallel (faster)
./tests/run_tests.sh -p
```

## Test Results

### Exit Codes
- `0` - All tests passed
- `1` - Some tests failed

### Output Format
```
AppImage Desktop Integrator Test Runner
========================================

[INFO] Checking prerequisites...
[SUCCESS] Prerequisites check passed
[INFO] Running test suites: basic appimage edge

Running Basic Functionality tests...
========================================
[SUCCESS] PASS: Status command should succeed
[SUCCESS] PASS: Desktop directory should be created
...
[SUCCESS] Basic Functionality tests PASSED
  Tests: 15 passed, 0 failed, 15 total
Duration: 3s

===============================================
Overall Test Results Summary
===============================================
Test Suites:
  Total: 3
  Passed: 3
  Failed: 0

Individual Tests:
  Total: 45
  Passed: 45
  Failed: 0

Success Rate: 100.0%

[SUCCESS] All test suites passed! 🎉
Total Duration: 12s
```

## Debugging Failed Tests

### Preserve Test Environment
```bash
# Run tests without cleanup
./tests/run_tests.sh --no-cleanup

# Examine test environment
ls -la /tmp/appimage_integrator_tests/test_*/
```

### Verbose Output
```bash
# See detailed test execution
./tests/run_tests.sh -v basic
```

### Manual Test Environment
```bash
# Source the test framework for manual testing
source ./tests/test_framework.sh

# Initialize test environment
init_test_framework

# Your test environment is now available:
echo $TEST_HOME
ls $TEST_ENV_DIR
```

## Writing New Tests

### Adding to Existing Suites

```bash
# In test_basic_functionality.sh
test_my_new_feature() {
    log_info "Testing my new feature"
    
    # Your test code here
    local output
    output=$("$TEST_ENV_DIR/bin/ai_test" my_command 2>&1)
    
    assert_equal 0 $? "My command should succeed"
    assert_equal 1 "$(echo "$output" | grep -c "expected text")" "Should contain expected text"
}

# Add to run_basic_tests() function
run_basic_tests() {
    # ... existing tests ...
    test_my_new_feature
    # ...
}
```

### Creating New Test Suite

1. Create new test file: `test_my_suite.sh`
2. Source the test framework: `source test_framework.sh`
3. Write test functions using assertions
4. Create main function that calls `init_test_framework`
5. Add to `run_tests.sh` in the suite selection logic

### Best Practices

- Always use `init_test_framework` to set up isolated environment
- Use descriptive test function names: `test_specific_functionality`
- Include meaningful assertion messages
- Test both success and failure scenarios
- Clean up any additional resources you create
- Use the provided mock AppImages rather than real ones

## Test Environment Structure

```
/tmp/appimage_integrator_tests/test_<session_id>/
├── home/                           # Mock HOME directory
│   ├── .config/
│   │   └── appimage_desktop_integrator/
│   │       ├── config.ini         # Test config
│   │       ├── VERSION           # Version file
│   │       ├── logs/             # Application logs
│   │       └── bin/
│   │           └── appimage-run-wrapper.sh
│   ├── .local/share/
│   │   ├── applications/         # Desktop entries
│   │   └── icons/appimage-integrator/  # Icons
│   ├── Downloads/                # Mock Downloads
│   ├── Desktop/                  # Mock Desktop
│   ├── Applications/             # Mock Applications
│   ├── AppImages/               # Mock AppImages
│   └── apps/                    # Mock apps
├── appimages/samples/           # Mock AppImage files
└── bin/                        # Test scripts
    ├── install_appimages       # Copy of main script
    └── ai_test                # Test wrapper
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: ./tests/run_tests.sh
```

### Requirements
- Linux environment (Ubuntu, Debian, etc.)
- Bash 4.0+
- Standard Unix utilities (grep, sed, awk, find, etc.)
- No root privileges required
- No external dependencies

## Troubleshooting

### Common Issues

**Tests fail with "command not found"**
- Ensure all test scripts are executable: `chmod +x tests/*.sh`
- Check that required commands are available

**Permission denied errors**
- Ensure `/tmp` is writable
- Don't run tests as root

**Tests hang or timeout**
- Check for background processes in test environment
- Ensure mock AppImages aren't actually running

**Cleanup issues**
- Use `--no-cleanup` flag to preserve environment
- Manually clean: `rm -rf /tmp/appimage_integrator_tests/*`

### Getting Help

1. Run with verbose output: `./tests/run_tests.sh -v`
2. Preserve test environment: `./tests/run_tests.sh --no-cleanup`
3. Check individual test files for specific issues
4. Examine test framework code in `test_framework.sh`

## Contributing

When adding new features to the main application:

1. Write tests first (TDD approach)
2. Ensure all existing tests still pass
3. Add tests for edge cases
4. Update this documentation if needed
5. Run full test suite before submitting PRs

The test suite should provide confidence that changes don't break existing functionality and that new features work as expected across various scenarios.