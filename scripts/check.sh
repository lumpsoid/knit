#!/usr/bin/env bash
#
# check.sh — every gate CI runs, in CI's order; stops at the first failure.
#
# Usage: scripts/check.sh

set -euo pipefail

cd "$(dirname -- "${BASH_SOURCE[0]}")/.."

if command -v fvm >/dev/null 2>&1; then FLUTTER=(fvm flutter); DART=(fvm dart); else FLUTTER=(flutter); DART=(dart); fi

step() { printf '\n== %s\n' "$*"; }

step "version"
scripts/version.sh check

step "pub get"
"${FLUTTER[@]}" pub get
for pkg in packages/*/; do (cd "${pkg}" && "${FLUTTER[@]}" pub get >/dev/null); done

step "format"
"${DART[@]}" format --output=none --set-exit-if-changed lib test packages

step "analyze"
"${FLUTTER[@]}" analyze lib test packages

step "test"
"${FLUTTER[@]}" test
for pkg in packages/*/; do (cd "${pkg}" && "${FLUTTER[@]}" test); done

printf '\nAll gates passed.\n'
