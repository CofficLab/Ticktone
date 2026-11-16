#!/usr/bin/env bash
#
# bump-version.sh - Determine version increment from Conventional Commits
#
# Analyzes commits since the last v* tag and outputs the increment type:
#   major - breaking changes (BREAKING CHANGE, feat!, fix!, refactor!)
#   minor - new features (feat:)
#   patch - everything else (fix:, chore:, docs:, etc.)
#
# Usage: ./bump-version.sh
# Output: major | minor | patch
#

set -euo pipefail

# Find the most recent v* tag by version order (not just git reachability)
LAST_TAG=$(git tag -l "v*" | sort -V | tail -n 1 2>/dev/null || true)

# Get all commit messages since the last tag (or all commits if no tag exists)
if [ -n "$LAST_TAG" ]; then
  COMMITS=$(git log "${LAST_TAG}..HEAD" --pretty=format:%s 2>/dev/null || echo "")
else
  COMMITS=$(git log --pretty=format:%s 2>/dev/null || echo "")
fi

# Default to patch when no commits found
if [ -z "$COMMITS" ]; then
  echo "patch"
  exit 0
fi

# Breaking changes → major
# Matches: BREAKING CHANGE in body, or feat!:/fix!:/refactor!: in subject
if echo "$COMMITS" | grep -qE "BREAKING CHANGE|^feat!|^fix!|^refactor!"; then
  echo "major"
  exit 0
fi

# New features → minor
if echo "$COMMITS" | grep -qE "^feat:"; then
  echo "minor"
  exit 0
fi

# Bug fixes and other changes → patch
echo "patch"
