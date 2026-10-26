#!/usr/bin/env bash
#
# release_apk.sh — build a release APK and name it after the app + version.
#
# Usage:
#   scripts/release_apk.sh            # prod flavor
#   scripts/release_apk.sh staging    # or dev / staging / prod
#
# Output: dist/knit-<version>.apk (prod) or dist/knit-<flavor>-<version>.apk,
# where <version> is pubspec.yaml's `version:` (e.g. 1.0.6+7).

set -euo pipefail

cd "$(dirname -- "${BASH_SOURCE[0]}")/.."

FLAVOR="${1:-prod}"
case "${FLAVOR}" in
  dev|staging|prod) ;;
  *) echo "error: flavor must be dev, staging or prod (got '${FLAVOR}')" >&2; exit 1 ;;
esac

APP="$(sed -n 's/^name:[[:space:]]*//p' pubspec.yaml | tr -d '[:space:]')"
VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | tr -d '[:space:]')"
[ -n "${APP}" ] && [ -n "${VERSION}" ] || { echo "error: no name/version in pubspec.yaml" >&2; exit 1; }

# Prefer fvm when the project is pinned through it.
if command -v fvm >/dev/null 2>&1; then FLUTTER=(fvm flutter); else FLUTTER=(flutter); fi

"${FLUTTER[@]}" build apk --release --flavor "${FLAVOR}" --target "lib/main_${FLAVOR}.dart"

if [ "${FLAVOR}" = prod ]; then NAME="${APP}-${VERSION}.apk"; else NAME="${APP}-${FLAVOR}-${VERSION}.apk"; fi
mkdir -p dist
cp "build/app/outputs/flutter-apk/app-${FLAVOR}-release.apk" "dist/${NAME}"

echo
echo "Built dist/${NAME}"
