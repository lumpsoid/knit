#!/usr/bin/env bash
#
# build_release.sh — build a flavored Knit release artifact, then package it
# alongside a SHA-256 checksum so the artifact can be verified after transfer.
#
# Usage:
#   scripts/build_release.sh --flavor=staging --platform=android
#   scripts/build_release.sh --flavor=prod --platform=android --type=appbundle
#   scripts/build_release.sh --flavor=staging --platform=ios
#
# Flags:
#   --flavor=<dev|staging|prod>   required; selects flavor + lib/main_<flavor>.dart
#   --platform=<android|ios>      required; build target
#   --type=<apk|appbundle>        android only; default: apk
#   -h, --help                    show this help
#
# Output (under dist/):
#   knit-<flavor>-<platform>-<gitsha>.zip   the artifact, zipped
#   knit-<flavor>-<platform>-<gitsha>.zip.sha256   its checksum
#
# Verify a downloaded zip with:
#   sha256sum -c knit-<...>.zip.sha256

set -euo pipefail

# --- locate repo root (script lives in scripts/) -----------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
cd "${REPO_ROOT}"

# --- defaults & arg parsing ---------------------------------------------------
FLAVOR=""
PLATFORM=""
BUILD_TYPE="apk"

usage() {
  sed -n '3,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

for arg in "$@"; do
  case "${arg}" in
    --flavor=*)   FLAVOR="${arg#*=}" ;;
    --platform=*) PLATFORM="${arg#*=}" ;;
    --type=*)     BUILD_TYPE="${arg#*=}" ;;
    -h|--help)    usage 0 ;;
    *) echo "error: unknown argument '${arg}'" >&2; usage 1 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }

# --- validate -----------------------------------------------------------------
case "${FLAVOR}" in
  dev|staging|prod) ;;
  "") die "--flavor is required (dev|staging|prod)" ;;
  *)  die "invalid --flavor '${FLAVOR}' (expected dev|staging|prod)" ;;
esac

case "${PLATFORM}" in
  android|ios) ;;
  "") die "--platform is required (android|ios)" ;;
  *)  die "invalid --platform '${PLATFORM}' (expected android|ios)" ;;
esac

TARGET="lib/main_${FLAVOR}.dart"
[ -f "${TARGET}" ] || die "entrypoint '${TARGET}' not found"

# --- build --------------------------------------------------------------------
GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
ARTIFACT=""   # path to the built file/dir we will zip

build_android() {
  case "${BUILD_TYPE}" in
    apk)
      echo ">> fvm flutter build apk --release --flavor ${FLAVOR} --target ${TARGET}"
      fvm flutter build apk --release --flavor "${FLAVOR}" --target "${TARGET}"
      ARTIFACT="build/app/outputs/flutter-apk/app-${FLAVOR}-release.apk"
      ;;
    appbundle)
      echo ">> fvm flutter build appbundle --release --flavor ${FLAVOR} --target ${TARGET}"
      fvm flutter build appbundle --release --flavor "${FLAVOR}" --target "${TARGET}"
      ARTIFACT="build/app/outputs/bundle/${FLAVOR}Release/app-${FLAVOR}-release.aab"
      ;;
    *) die "invalid --type '${BUILD_TYPE}' (expected apk|appbundle)" ;;
  esac
}

build_ios() {
  # NOTE: iOS has only the single 'Runner' scheme today (no per-flavor schemes),
  # so --flavor is passed through but won't switch bundle ids until schemes exist.
  echo ">> fvm flutter build ipa --release --flavor ${FLAVOR} --target ${TARGET}"
  fvm flutter build ipa --release --flavor "${FLAVOR}" --target "${TARGET}"
  ARTIFACT="$(find build/ios/ipa -maxdepth 1 -name '*.ipa' | head -n1)"
}

case "${PLATFORM}" in
  android) build_android ;;
  ios)     build_ios ;;
esac

[ -n "${ARTIFACT}" ] && [ -e "${ARTIFACT}" ] || die "expected artifact not found: '${ARTIFACT}'"

# --- package + checksum -------------------------------------------------------
DIST_DIR="${REPO_ROOT}/dist"
mkdir -p "${DIST_DIR}"

BASENAME="knit-${FLAVOR}-${PLATFORM}-${GIT_SHA}"
ZIP_PATH="${DIST_DIR}/${BASENAME}.zip"
SUM_PATH="${ZIP_PATH}.sha256"

rm -f "${ZIP_PATH}" "${SUM_PATH}"

# zip the artifact with a flat path (-j) so the entry is just the file name.
echo ">> zipping $(basename "${ARTIFACT}") -> ${ZIP_PATH}"
zip -j -q "${ZIP_PATH}" "${ARTIFACT}"

# sha256 over the zip; store as a relative path so `sha256sum -c` works from dist/.
echo ">> writing checksum -> ${SUM_PATH}"
( cd "${DIST_DIR}" && sha256sum "${BASENAME}.zip" > "$(basename "${SUM_PATH}")" )

echo
echo "Done."
echo "  artifact : ${ARTIFACT}"
echo "  zip      : ${ZIP_PATH}"
echo "  sha256   : $(cut -d' ' -f1 "${SUM_PATH}")"
echo
echo "Verify with:  ( cd '${DIST_DIR}' && sha256sum -c '$(basename "${SUM_PATH}")' )"
