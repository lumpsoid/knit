#!/usr/bin/env bash
#
# version.sh — the app version lives in pubspec.yaml (`version: X.Y.Z+N`; N is
# the Android versionCode and must grow every release).
#
# Usage:
#   scripts/version.sh show          # print X.Y.Z+N
#   scripts/version.sh check         # the version is well-formed and CHANGELOG.md
#                                    # has an [Unreleased] or [X.Y.Z] section
#   scripts/version.sh bump X.Y.Z    # set X.Y.Z+(N+1) and date [Unreleased]
#                                    # as [X.Y.Z] in CHANGELOG.md

set -euo pipefail

cd "$(dirname -- "${BASH_SOURCE[0]}")/.."

PUBSPEC=pubspec.yaml
CHANGELOG=CHANGELOG.md

die() { echo "error: $*" >&2; exit 1; }

current() { sed -n 's/^version:[[:space:]]*//p' "${PUBSPEC}" | tr -d '[:space:]'; }

parse() {
  local v
  v="$(current)"
  [[ "${v}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]] \
    || die "${PUBSPEC} version '${v}' is not X.Y.Z+N"
  NAME="${BASH_REMATCH[1]}"
  CODE="${BASH_REMATCH[2]}"
}

case "${1:-}" in
  show)
    echo "$(current)"
    ;;
  check)
    parse
    grep -qE "^## \[(Unreleased|${NAME//./\\.})\]" "${CHANGELOG}" \
      || die "${CHANGELOG} has neither [Unreleased] nor [${NAME}]"
    echo "version ${NAME}+${CODE} ok"
    ;;
  bump)
    NEW="${2:-}"
    [[ "${NEW}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: $0 bump X.Y.Z"
    parse
    [ "${NEW}" != "${NAME}" ] || die "already at ${NAME}"
    grep -q '^## \[Unreleased\]' "${CHANGELOG}" || die "${CHANGELOG} has no [Unreleased] section"
    ! grep -qE "^## \[${NEW//./\\.}\]" "${CHANGELOG}" || die "${CHANGELOG} already has [${NEW}]"
    NEXT="${NEW}+$((CODE + 1))"
    sed -i "s/^version:.*/version: ${NEXT}/" "${PUBSPEC}"
    # Date the release and open a fresh, empty [Unreleased] above it.
    sed -i "s/^## \[Unreleased\]\$/## [Unreleased]\n\n## [${NEW}] — $(date +%F)/" "${CHANGELOG}"
    echo "${NAME}+${CODE} -> ${NEXT}"
    ;;
  *)
    sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
