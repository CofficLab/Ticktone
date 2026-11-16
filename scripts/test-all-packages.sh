#!/bin/bash
# Run `swift test` for every package that has a Tests directory.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

status=0
for package in Packages/*/Package.swift; do
    package_dir="$(dirname "$package")"
    if [ -d "$package_dir/Tests" ]; then
        echo "==> $package_dir"
        if ! (cd "$package_dir" && swift test); then
            status=1
        fi
    fi
done

exit "$status"
