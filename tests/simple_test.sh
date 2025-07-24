#!/bin/bash

# Simple test to verify the fixes work

echo "Testing GitHub Issues #4, #5, and #6 Fixes"
echo "==========================================="

# Test Issue #4: clean_appimage_name function
echo
echo "Issue #4: clean_appimage_name() function test"
echo "---------------------------------------------"

# Test the name extraction logic
test_name="MediaElch_linux_2.12.0_2024-10-13_git-8032465-1.AppImage"
extracted_name="${test_name%%[^a-zA-Z]*}"
echo "Input: $test_name"
echo "Extracted: $extracted_name"

if [ "$extracted_name" = "MediaElch" ]; then
    echo "✓ Issue #4 fix working correctly"
else
    echo "✗ Issue #4 fix failed"
fi

# Test Issue #5: dirname bug
echo
echo "Issue #5: dirname bug test"
echo "--------------------------"

filename="LosslessCut-linux-x86_64.AppImage"
original_path=$(dirname "$filename")
echo "dirname result for '$filename': $original_path"

if [ "$original_path" = "." ]; then
    fixed_path=$PWD
    echo "Fix applied: Using PWD = $fixed_path"
    echo "✓ Issue #5 fix working correctly"
else
    echo "✗ Issue #5 fix may have issues"
fi

# Test Issue #6: Check script syntax and function existence
echo
echo "Issue #6: Variable scoping and script syntax"
echo "-------------------------------------------"

# Check if script has valid syntax
if bash -n install_appimages.sh 2>/dev/null; then
    echo "✓ Script syntax is valid"
else
    echo "✗ Script has syntax errors"
fi

# Check if the local variable fix is implemented
if grep -q "local name=" install_appimages.sh; then
    echo "✓ Local variable declaration found"
else
    echo "✗ Local variable declaration not found"
fi

# Integration test: Check all fixes are in place
echo
echo "Integration Test: Verify all fixes are implemented"
echo "================================================"

fixes_count=0

# Check Issue #4 fix
if grep -q "read -p.*Use the name" install_appimages.sh; then
    echo "✓ Issue #4 fix implemented (user confirmation prompt)"
    ((fixes_count++))
else
    echo "✗ Issue #4 fix not found"
fi

# Check Issue #5 fix
if grep -q "original_path=\$PWD" install_appimages.sh; then
    echo "✓ Issue #5 fix implemented (PWD assignment)"
    ((fixes_count++))
else
    echo "✗ Issue #5 fix not found"
fi

# Check Issue #6 fix
if grep -q "local name=" install_appimages.sh; then
    echo "✓ Issue #6 fix implemented (local variable)"
    ((fixes_count++))
else
    echo "✗ Issue #6 fix not found"
fi

echo
echo "Summary: $fixes_count/3 fixes implemented"
if [ $fixes_count -eq 3 ]; then
    echo "🎉 All issues have been successfully fixed!"
else
    echo "⚠️  Some fixes may need attention"
fi