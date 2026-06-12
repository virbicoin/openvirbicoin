#!/usr/bin/env bash
#
# release.sh — Semi-automated helper for the openvirbicoin (ovbc) release cycle.
#
# Branch model (go-virbicoin / go-ethereum style):
#   - main          : Mainline development. Always vX.Y.Z, built as "unstable".
#   - dev           : Feature integration and verification.
#   - release/X.Y   : Maintenance line. Stable release tags live here.
#
# Release cycle:
#   1. Development : main is vX.Y.Z and is built without `--features final`, so
#                    the client reports "Ovbc/vX.Y.Z-unstable/...".
#   2. Release     : merge main into release/X.Y, tag vX.Y.Z and push. The
#                    release workflow builds the plain tag with `--features
#                    final`, so the published binaries report
#                    "Ovbc/vX.Y.Z-stable/...".
#   3. Post-release: bump main's patch number for the next development cycle
#                    (main stays "unstable").
#
# Unlike go-virbicoin (which runs GoReleaser locally), the openvirbicoin release
# binaries are produced by the GitHub Actions workflow
# (.github/workflows/release.yml) when the vX.Y.Z tag is pushed. This script only
# drives the git/branch/tag flow and then leaves the draft release for you to
# review and publish.
#
# Usage:
#   build/release.sh            Release main's version as a stable build on
#                               release/X.Y, then advance main to the next patch.
#   build/release.sh --dry-run  Print the steps without making any changes,
#                               pushes, or releases.
#
# Requirements:
#   - Clean working tree (no uncommitted changes)
#   - Run from the main branch
#   - GITHUB_TOKEN (or GH_TOKEN) must be set (~/.gvbc_token.env is sourced)
#
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

ROOT_MANIFEST="Cargo.toml"
VERSION_MANIFEST="crates/util/version/Cargo.toml"
REPO="virbicoin/open-virbicoin"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }
run()  { if [[ $DRY_RUN -eq 1 ]]; then printf '   (dry-run) %s\n' "$*"; else eval "$*"; fi; }

# --- Load token ---
if [[ -z "${GITHUB_TOKEN:-}" && -f "$HOME/.gvbc_token.env" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/.gvbc_token.env"
fi
GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

# --- Preflight checks ---
[[ -n "${GITHUB_TOKEN:-}" ]] || err "GITHUB_TOKEN is not set (check ~/.gvbc_token.env)"

branch="$(git rev-parse --abbrev-ref HEAD)"
[[ "$branch" == "main" ]] || err "Run from the main branch (current: $branch)"

if [[ -n "$(git status --porcelain)" ]]; then
  err "Working tree has uncommitted changes. Commit or stash them first."
fi

# --- Read the current version from the root manifest ---
VERSION="$(grep -m1 -E '^version = ' "$ROOT_MANIFEST" | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || err "Could not read a semver version from $ROOT_MANIFEST"
MAJOR="${VERSION%%.*}"
REST="${VERSION#*.}"
MINOR="${REST%%.*}"
PATCH="${VERSION##*.}"

CUR_TAG="v${VERSION}"
RELEASE_BRANCH="release/${MAJOR}.${MINOR}"
NEXT_PATCH=$((PATCH + 1))
NEXT_VERSION="${MAJOR}.${MINOR}.${NEXT_PATCH}"

log "Current version: ${CUR_TAG} (unstable on main)"
log "Release branch:  ${RELEASE_BRANCH}"
log "Next dev cycle:  v${NEXT_VERSION} (unstable)"

# Cleanup: always return to main on exit
cleanup() { git checkout main >/dev/null 2>&1 || true; }
trap cleanup EXIT

# --- 0) Fetch latest ---
log "[0/5] Fetch the latest from the remote"
run "git fetch origin --prune"

# --- 1) Prepare release/X.Y and merge main ---
log "[1/5] Merge main into ${RELEASE_BRANCH}"
if git show-ref --verify --quiet "refs/remotes/origin/${RELEASE_BRANCH}"; then
  run "git checkout -B \"$RELEASE_BRANCH\" \"origin/${RELEASE_BRANCH}\""
  run "git merge --no-edit main"
else
  log "  ${RELEASE_BRANCH} does not exist; creating it from main"
  run "git checkout -B \"$RELEASE_BRANCH\" main"
fi

# --- 2) Tag the stable release and push (triggers the release workflow) ---
log "[2/5] Tag ${CUR_TAG} on ${RELEASE_BRANCH} and push"
run "git tag -f \"$CUR_TAG\""
run "git push origin \"$RELEASE_BRANCH\""
run "git push -f origin \"$CUR_TAG\""

# --- 3) Delete any existing draft for this tag ---
log "[3/5] Check for and delete an existing draft for ${CUR_TAG}"
if [[ $DRY_RUN -eq 0 ]]; then
  RID="$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/${REPO}/releases?per_page=20" \
    | python3 -c "import sys,json
for r in json.load(sys.stdin):
    if r.get('tag_name')=='$CUR_TAG' and r.get('draft'):
        print(r['id']); break" 2>/dev/null || true)"
  if [[ -n "${RID:-}" ]]; then
    curl -s -X DELETE -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/repos/${REPO}/releases/$RID" \
      -w "   Deleted existing draft ($RID): HTTP=%{http_code}\n"
  else
    echo "   No existing draft"
  fi
else
  echo "   (dry-run) Skipping draft check/delete"
fi

log "    The release workflow now builds ${CUR_TAG} with --features final and"
log "    creates a draft release. Review and publish it from the Releases page."

# --- 4) Advance main to the next development cycle (unstable) ---
log "[4/5] Bump main to v${NEXT_VERSION} for the next development cycle"
run "git checkout main"
# main is already unstable (no `final` feature), so only the version changes.
# Keep the root crate and the version crate in lock step.
run "sed -i -E 's/^version = \"${VERSION}\"/version = \"${NEXT_VERSION}\"/' \"$ROOT_MANIFEST\""
run "sed -i -E 's/^version = \"${VERSION}\"/version = \"${NEXT_VERSION}\"/' \"$VERSION_MANIFEST\""
# Keep Cargo.lock in sync so CI builds the new version without a lock mismatch.
# Only the two workspace crates (openethereum, parity-version) carry this
# version, so a direct, offline rewrite is safe and avoids re-resolving the old
# OpenEthereum git dependencies (which `cargo update` can fail on).
run "sed -i -E 's/^version = \"${VERSION}\"\$/version = \"${NEXT_VERSION}\"/' Cargo.lock"
run "git add \"$ROOT_MANIFEST\" \"$VERSION_MANIFEST\" Cargo.lock"
run "git commit -m \"Begin next development cycle: v${NEXT_VERSION} unstable\""
run "git push origin main"

# --- 5) Done ---
log "[5/5] Done"
echo "   Released ${CUR_TAG} (stable, draft) from ${RELEASE_BRANCH}."
echo "   main is now v${NEXT_VERSION} (unstable)."
echo "   Review the draft on the GitHub releases page and publish it when ready."
