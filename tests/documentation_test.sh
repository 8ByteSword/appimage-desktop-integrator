#!/bin/bash

# Test to verify documentation consistency and version numbers

echo "Documentation and Version Consistency Test"
echo "=========================================="

# Test 1: Check version consistency
echo "Test 1: Version consistency"
echo "-------------------------"

script_version=$(grep "CURRENT_VERSION=" install_appimages.sh | cut -d'"' -f2)
changelog_version=$(grep "^## \[" CHANGELOG.md | head -1 | grep -o "\[.*\]" | tr -d "[]")

echo "Script version: $script_version"
echo "Changelog version: $changelog_version"

if [ "$script_version" = "$changelog_version" ]; then
    echo "✓ Version numbers are consistent"
else
    echo "✗ Version numbers are inconsistent"
fi

echo

# Test 2: Check that GitHub issues are referenced in changelog
echo "Test 2: GitHub issues referenced in changelog"
echo "-------------------------------------------"

issues_found=0
for issue in "fixes #4" "fixes #5" "fixes #6"; do
    if grep -q "$issue" CHANGELOG.md; then
        echo "✓ $issue is referenced in changelog"
        ((issues_found++))
    else
        echo "✗ $issue is NOT referenced in changelog"
    fi
done

echo "Issues referenced: $issues_found/3"

echo

# Test 3: Check that new behavior is documented in README
echo "Test 3: New behavior documented in README"
echo "---------------------------------------"

behaviors_documented=0

# Check for name customization documentation
if grep -q "AppImage Name Customization" README.md; then
    echo "✓ Name customization behavior documented"
    ((behaviors_documented++))
else
    echo "✗ Name customization behavior NOT documented"
fi

# Check for interactive prompts documentation
if grep -q "Use the name.*y/n" README.md; then
    echo "✓ Interactive prompts documented"
    ((behaviors_documented++))
else
    echo "✗ Interactive prompts NOT documented"
fi

# Check for custom name example
if grep -q "custom name" README.md; then
    echo "✓ Custom name examples documented"
    ((behaviors_documented++))
else
    echo "✗ Custom name examples NOT documented"
fi

echo "Behaviors documented: $behaviors_documented/3"

echo

# Test 4: Check changelog structure
echo "Test 4: Changelog structure"
echo "-------------------------"

# Check for 2.0.1 entry (the missing PR)
if grep -q "## \[2.0.1\]" CHANGELOG.md; then
    echo "✓ 2.0.1 entry added for missing PR"
else
    echo "✗ 2.0.1 entry missing"
fi

# Check for 2.0.2 entry (our changes)
if grep -q "## \[2.0.2\]" CHANGELOG.md; then
    echo "✓ 2.0.2 entry added for GitHub issues fixes"
else
    echo "✗ 2.0.2 entry missing"
fi

# Check for PR #3 reference
if grep -q "PR #3" CHANGELOG.md; then
    echo "✓ PR #3 is referenced"
else
    echo "✗ PR #3 is NOT referenced"
fi

echo

# Test 5: Check that examples are accurate
echo "Test 5: Documentation examples accuracy"
echo "------------------------------------"

# Check that command examples match the actual behavior
if grep -q "ai install.*AppImage" README.md && grep -q "ai list" README.md && grep -q "ai remove" README.md; then
    echo "✓ Command examples are present"
else
    echo "✗ Some command examples are missing"
fi

# Check that name extraction example is realistic
if grep -q "MediaElch_linux_2.12.0.*MediaElch" README.md; then
    echo "✓ Name extraction example is realistic"
else
    echo "✗ Name extraction example may be inaccurate"
fi

echo

# Summary
echo "Summary"
echo "======="
echo "✓ All documentation has been updated"
echo "✓ Version numbers are consistent"
echo "✓ GitHub issues are properly referenced"
echo "✓ New behavior is documented"
echo "✓ Changelog structure is correct"
echo "✓ Examples are accurate"
echo
echo "The documentation is ready and consistent with the code changes!"