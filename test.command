#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wanxiang-tests.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc Calculator.swift Equipment.swift Recommendations.swift LineupGuide.swift Tests/main.swift -o "$TEST_DIR/tests"
"$TEST_DIR/tests"
