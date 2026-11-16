#!/usr/bin/env bash
#
# calculate-version.sh - Calculate the next semantic version
#
# Combines the version from project.yml (MARKETING_VERSION) and the latest
# git v* tag, then applies the bump determined by bump-version.sh.
#
# If MARKETING_VERSION in project.yml is already ahead of the latest tag,
# it is used as-is (respects manual version bumps in the repo).
#
# Usage: ./calculate-version.sh
# Output: <version> (e.g., 1.2.3)
#

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Latest v* tag (version-sorted, not reachability-sorted)
LAST_TAG=$(git tag -l "v*" | sort -V | tail -n 1 2>/dev/null || true)
if [ -n "$LAST_TAG" ]; then
  LAST_TAG="${LAST_TAG#v}"
else
  LAST_TAG="0.0.0"
fi

# Read MARKETING_VERSION from XcodeGen project.yml
PROJECT_YML="project.yml"
if [ ! -f "$PROJECT_YML" ]; then
  echo "error: project.yml not found" >&2
  exit 1
fi

YML_VERSION=$(grep -m1 "MARKETING_VERSION:" "$PROJECT_YML" | sed 's/.*MARKETING_VERSION:[[:space:]]*//' | sed 's/^"//; s/"$//' | tr -d ' ' || echo "0.0.0")

# Prefer whichever is higher: tag or project.yml
BASE_VERSION=$(printf '%s\n' "${LAST_TAG}" "${YML_VERSION}" | sort -V | tail -n 1)

echo "Git tag version: ${LAST_TAG}" >&2
echo "project.yml version: ${YML_VERSION}" >&2

# If project.yml is explicitly ahead, use it as-is (manual version bump wins)
if [[ "${YML_VERSION}" != "${LAST_TAG}" && "${BASE_VERSION}" == "${YML_VERSION}" ]]; then
  echo "Using repository version: ${YML_VERSION}" >&2
  echo "${YML_VERSION}"
  exit 0
fi

echo "Using base version: ${BASE_VERSION}" >&2

# Get increment type from bump-version.sh
INCREMENT_TYPE=$("${SCRIPT_DIR}/bump-version.sh")

# Parse and bump
IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE_VERSION"
MAJOR=${MAJOR:-0}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

case $INCREMENT_TYPE in
  major) NEW_VERSION="$((MAJOR + 1)).0.0" ;;
  minor) NEW_VERSION="${MAJOR}.$((MINOR + 1)).0" ;;
  patch) NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
  *) echo "error: unknown increment type '$INCREMENT_TYPE'" >&2; exit 1 ;;
esac

echo "$NEW_VERSION"
