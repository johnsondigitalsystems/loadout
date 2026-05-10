#!/usr/bin/env bash
# FILE: scripts/upload_seed_data.sh
#
# ============================================================================
# WHAT THIS SCRIPT DOES
# ============================================================================
# Pushes the bundled `assets/seed_data/` reference catalog up to Firebase
# Storage so that LoadOut clients on user devices can pick up updated
# JSON without an App Store / Play Store release.
#
# For each file in `assets/seed_data/manifest.json`:
#   1. Hash the local copy (sha256) and the bucket copy (gsutil hash).
#   2. If they differ:
#      a. Copy the existing bucket file to `seed_data/archive/<base>-v<old>-<date>.json`
#         so old versions are preserved (CLAUDE.md § 28 — never delete).
#      b. Upload the local file to its canonical bucket path.
#   3. The manifest itself is uploaded LAST (after every payload) so
#      `SeedUpdater`'s anti-downgrade check never points at a version
#      whose payload file isn't published yet.
#
# Idempotent: running twice in a row is a no-op (every hash matches).
#
# Authentication: relies on `gcloud auth login --update-adc` having been
# run on this machine. The script doesn't take a service-account key —
# that's a v2 affordance we'll add when we want to drive this from CI.
#
# ============================================================================
# WHY IT EXISTS
# ============================================================================
# Without this script, "always sync the bucket on JSON changes" becomes a
# manual chore: run 24+ `gsutil cp` commands, remember to bump the manifest,
# remember to archive the old version, hope you don't typo a path. The
# CLAUDE.md instruction in § 28 only sticks if there's a one-command
# pushbutton to satisfy it.
#
# ============================================================================
# USAGE
# ============================================================================
#   # First time on a new machine:
#   gcloud auth login --update-adc
#   gcloud config set project loadout-precision-reloading
#
#   # Every time you want to publish JSON changes:
#   ./scripts/upload_seed_data.sh
#
#   # Dry-run mode — show what would be uploaded without writing:
#   ./scripts/upload_seed_data.sh --dry-run
#
# ============================================================================
# WHO CONSUMES IT
# ============================================================================
#   - The operator (you) when shipping a JSON catalog change.
#   - CI in the future, with an added `--service-account <key.json>` flag.
#
# ============================================================================
# SIDE EFFECTS
# ============================================================================
#   - Reads files from `assets/seed_data/`.
#   - Writes objects to `gs://loadout-precision-reloading.firebasestorage.app/seed_data/`.
#   - Writes archive copies to `seed_data/archive/`.
#   - Writes the updated manifest to `seed_data/manifest.json`.
#   - Does NOT touch user data anywhere — the bucket is reference-only
#     (CLAUDE.md § 13).

set -euo pipefail

BUCKET="gs://loadout-precision-reloading.firebasestorage.app"
SEED_PREFIX="seed_data"
ARCHIVE_PREFIX="seed_data/archive"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_SEED_DIR="$PROJECT_ROOT/assets/seed_data"
LOCAL_MANIFEST="$LOCAL_SEED_DIR/manifest.json"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  echo "DRY RUN — no uploads will be performed"
  echo ""
fi

# ─── Pre-flight checks ───────────────────────────────────────────────
command -v gsutil >/dev/null 2>&1 || {
  echo "ERROR: gsutil not on PATH. Install Google Cloud SDK." >&2
  exit 1
}
command -v firebase >/dev/null 2>&1 || {
  echo "ERROR: firebase CLI not on PATH. \`npm install -g firebase-tools\`." >&2
  exit 1
}
[[ -f "$LOCAL_MANIFEST" ]] || {
  echo "ERROR: missing $LOCAL_MANIFEST" >&2
  exit 1
}

# Verify gcloud is authenticated against the right project.
ACTIVE_PROJECT="$(gcloud config get-value project 2>/dev/null)"
if [[ "$ACTIVE_PROJECT" != "loadout-precision-reloading" ]]; then
  echo "ERROR: gcloud project is '$ACTIVE_PROJECT', expected 'loadout-precision-reloading'." >&2
  echo "Run: gcloud config set project loadout-precision-reloading" >&2
  exit 1
fi

# Probe the bucket — fails fast if ADC is stale.
if ! gsutil ls "$BUCKET/" >/dev/null 2>&1; then
  echo "ERROR: cannot list $BUCKET. Run: gcloud auth login --update-adc" >&2
  exit 1
fi

# ─── Helpers ─────────────────────────────────────────────────────────
sha256_local() { shasum -a 256 "$1" | awk '{print $1}'; }

# Returns the bucket object's md5Hash (base64) translated to hex, or empty
# if the object doesn't exist.
md5_remote() {
  local path="$1"
  local out
  out="$(gsutil hash -m -h "$BUCKET/$path" 2>/dev/null || true)"
  echo "$out" | awk -F': *' '/Hash \(md5\)/ {print $2}' | tr -d '[:space:]'
}

remote_exists() {
  gsutil -q stat "$BUCKET/$1" 2>/dev/null
}

# ─── Walk the manifest ───────────────────────────────────────────────
DATE_TAG="$(date -u +%Y%m%d-%H%M%S)"
UPLOADED=0
ARCHIVED=0
SKIPPED=0

# `python3` parses JSON safely without forcing a `jq` dependency.
# Pipe a tab-separated stream of "<key>\t<version>\t<filename>" rows
# into a while-read loop — `mapfile` would be cleaner but it's a bash
# 4+ builtin and macOS ships bash 3.2 by default.
MANIFEST_TSV="$(
  python3 - "$LOCAL_MANIFEST" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[1]))
for key, spec in manifest.get('files', {}).items():
    print(f"{key}\t{spec['version']}\t{spec['filename']}")
PY
)"

while IFS=$'\t' read -r KEY VERSION FILENAME; do
  [[ -z "$KEY" ]] && continue
  LOCAL_FILE="$LOCAL_SEED_DIR/$FILENAME"
  REMOTE_PATH="$SEED_PREFIX/$FILENAME"

  if [[ ! -f "$LOCAL_FILE" ]]; then
    echo "  SKIP    $KEY: local file missing ($FILENAME)" >&2
    continue
  fi

  LOCAL_HASH="$(sha256_local "$LOCAL_FILE")"
  if remote_exists "$REMOTE_PATH"; then
    # Pull the remote file into a temp and hash locally so SHA-256
    # comparison is symmetric. md5 hashes from `gsutil hash` are
    # base64 — converting just to compare is fiddly.
    TMP="$(mktemp)"
    gsutil -q cp "$BUCKET/$REMOTE_PATH" "$TMP"
    REMOTE_HASH="$(sha256_local "$TMP")"
    rm -f "$TMP"
  else
    REMOTE_HASH=""
  fi

  if [[ "$LOCAL_HASH" == "$REMOTE_HASH" ]]; then
    echo "  =       $KEY: hash matches (v$VERSION, $FILENAME)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Archive existing remote copy before overwriting (skip if it didn't
  # exist yet — first publish).
  if [[ -n "$REMOTE_HASH" ]]; then
    BASENAME="$(basename "$FILENAME" .json)"
    ARCHIVE_PATH="$ARCHIVE_PREFIX/${BASENAME}-v${VERSION}-${DATE_TAG}.json"
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "  archive $KEY: would archive $REMOTE_PATH → $ARCHIVE_PATH"
    else
      gsutil -q cp "$BUCKET/$REMOTE_PATH" "$BUCKET/$ARCHIVE_PATH"
      echo "  archive $KEY: archived $REMOTE_PATH → $ARCHIVE_PATH"
    fi
    ARCHIVED=$((ARCHIVED + 1))
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  upload  $KEY: would upload $FILENAME (v$VERSION)"
  else
    gsutil -q -h "Content-Type:application/json; charset=utf-8" \
      -h "Cache-Control:public, max-age=300" \
      cp "$LOCAL_FILE" "$BUCKET/$REMOTE_PATH"
    echo "  upload  $KEY: uploaded $FILENAME (v$VERSION)"
  fi
  UPLOADED=$((UPLOADED + 1))
done <<< "$MANIFEST_TSV"

# ─── Manifest itself, last ───────────────────────────────────────────
# Upload the manifest only after every payload it points at has been
# published. SeedUpdater's anti-downgrade check looks at the manifest
# first and downloads the matching payload after — if we wrote the
# manifest first, a client could see "v5" in the manifest but fetch
# v4 data because the v5 payload upload hadn't started yet.
MANIFEST_REMOTE="$SEED_PREFIX/manifest.json"
LOCAL_MANIFEST_HASH="$(sha256_local "$LOCAL_MANIFEST")"
if remote_exists "$MANIFEST_REMOTE"; then
  TMP="$(mktemp)"
  gsutil -q cp "$BUCKET/$MANIFEST_REMOTE" "$TMP"
  REMOTE_MANIFEST_HASH="$(sha256_local "$TMP")"
  rm -f "$TMP"
else
  REMOTE_MANIFEST_HASH=""
fi

if [[ "$LOCAL_MANIFEST_HASH" == "$REMOTE_MANIFEST_HASH" ]]; then
  echo "  =       manifest: hash matches"
else
  if [[ -n "$REMOTE_MANIFEST_HASH" ]]; then
    ARCHIVE_PATH="$ARCHIVE_PREFIX/manifest-${DATE_TAG}.json"
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "  archive manifest: would archive → $ARCHIVE_PATH"
    else
      gsutil -q cp "$BUCKET/$MANIFEST_REMOTE" "$BUCKET/$ARCHIVE_PATH"
      echo "  archive manifest: archived → $ARCHIVE_PATH"
    fi
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  upload  manifest: would upload"
  else
    gsutil -q -h "Content-Type:application/json; charset=utf-8" \
      -h "Cache-Control:public, max-age=60" \
      cp "$LOCAL_MANIFEST" "$BUCKET/$MANIFEST_REMOTE"
    echo "  upload  manifest: uploaded"
  fi
  UPLOADED=$((UPLOADED + 1))
fi

echo ""
echo "Summary: uploaded=$UPLOADED archived=$ARCHIVED skipped=$SKIPPED"

if [[ $DRY_RUN -eq 1 ]]; then
  echo ""
  echo "Dry run complete. Re-run without --dry-run to publish."
fi
