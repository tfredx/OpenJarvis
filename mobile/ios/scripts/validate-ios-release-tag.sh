#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
RELEASE_COMMIT="${2:-}"
INTEGRATION_COMMIT="${3:-}"
GIT_REPOSITORY="${4:-.}"
if [[ ! "$TAG" =~ ^ios-v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
  echo "Unsupported iOS release tag: $TAG" >&2
  exit 1
fi
VERSION="${BASH_REMATCH[1]}"
[[ -n "$RELEASE_COMMIT" && -n "$INTEGRATION_COMMIT" ]] || {
  echo 'Release and ios/main commit SHAs are required.' >&2
  exit 1
}
git -C "$GIT_REPOSITORY" merge-base --is-ancestor "$RELEASE_COMMIT" "$INTEGRATION_COMMIT" || {
  echo 'Release tag must point to a commit contained in ios/main.' >&2
  exit 1
}
printf '%s\n' "$VERSION"
