#!/usr/bin/env bash
#
# release.sh — tag the version in pubspec.yaml as vX.Y.Z, with its CHANGELOG.md
# section as the tag message. Runs every gate first. Never pushes.
#
# Usage: scripts/release.sh   (after `scripts/version.sh bump X.Y.Z` is committed)

set -euo pipefail

cd "$(dirname -- "${BASH_SOURCE[0]}")/.."

die() { echo "error: $*" >&2; exit 1; }

[ "$(git branch --show-current)" = master ] || die "not on master"
[ -z "$(git status --porcelain)" ] || die "working tree not clean"

VERSION="$(scripts/version.sh show)"
NAME="${VERSION%%+*}"
TAG="v${NAME}"

git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null && die "${TAG} already exists"

# The [X.Y.Z] section's body, up to the next section.
NOTES="$(awk -v v="${NAME}" '
  $0 ~ "^## \\[" v "\\]" { on = 1; next }
  on && /^## \[/ { exit }
  on { print }
' CHANGELOG.md | sed -e '/./,$!d')"
[ -n "${NOTES}" ] || die "CHANGELOG.md has no [${NAME}] section (run scripts/version.sh bump ${NAME})"

scripts/check.sh

# --cleanup=verbatim keeps the "### Added" lines, which the default cleanup
# would strip as comments.
printf 'Knit %s\n\n%s\n' "${NAME}" "${NOTES}" | git tag -a --cleanup=verbatim -F - "${TAG}"

echo
echo "Tagged ${TAG} (${VERSION}). Publish it with:"
echo "  git push origin master ${TAG}"
