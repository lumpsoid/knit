#!/usr/bin/env bash
#
# release_apk.sh — build a release APK and name it after the app + version,
# with a SHA-256 checksum beside it.
#
# Usage:
#   scripts/release_apk.sh            # prod flavor
#   scripts/release_apk.sh staging    # or dev / staging / prod
#
# Output: dist/knit-<version>.apk (prod) or dist/knit-<flavor>-<version>.apk,
# where <version> is pubspec.yaml's X.Y.Z, plus <apk>.sha256. The build carries
# the commit hash (About shows `X.Y.Z (abc1234)`). Signed with
# android/key.properties when present, else with the debug key.

set -euo pipefail

cd "$(dirname -- "${BASH_SOURCE[0]}")/.."

FLAVOR="${1:-prod}"
case "${FLAVOR}" in
  dev|staging|prod) ;;
  *) echo "error: flavor must be dev, staging or prod (got '${FLAVOR}')" >&2; exit 1 ;;
esac

APP="$(sed -n 's/^name:[[:space:]]*//p' pubspec.yaml | tr -d '[:space:]')"
VERSION="$(scripts/version.sh show)"
VERSION="${VERSION%%+*}"
COMMIT="$(git rev-parse HEAD 2>/dev/null || true)"

# Prefer fvm when the project is pinned through it.
if command -v fvm >/dev/null 2>&1; then FLUTTER=(fvm flutter); else FLUTTER=(flutter); fi

"${FLUTTER[@]}" build apk --release --flavor "${FLAVOR}" --target "lib/main_${FLAVOR}.dart" \
  --dart-define="GIT_COMMIT=${COMMIT}"

if [ "${FLAVOR}" = prod ]; then NAME="${APP}-${VERSION}.apk"; else NAME="${APP}-${FLAVOR}-${VERSION}.apk"; fi
mkdir -p dist
cp "build/app/outputs/flutter-apk/app-${FLAVOR}-release.apk" "dist/${NAME}"
(cd dist && sha256sum "${NAME}" > "${NAME}.sha256")

[ -f android/key.properties ] || echo "warning: no android/key.properties, signed with the debug key" >&2
echo
echo "Built dist/${NAME}"
