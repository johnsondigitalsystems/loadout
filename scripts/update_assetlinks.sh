#!/usr/bin/env bash
# Adds the release keystore SHA-256 to public/.well-known/assetlinks.json
# (preserving the existing debug SHA-256 already in the file).
#
# Usage:
#   ./scripts/update_assetlinks.sh                  # defaults: alias=loadout, store=android/app/loadout_release.keystore
#   ./scripts/update_assetlinks.sh --apply          # write changes to disk
#   ./scripts/update_assetlinks.sh --keystore PATH  # custom keystore path
#   ./scripts/update_assetlinks.sh --alias NAME     # custom key alias
#
# Default behaviour: dry-run. Prints the proposed merged JSON and a diff vs.
# the current file. Pass --apply to actually overwrite assetlinks.json.
#
# Reads the keystore password from android/key.properties if present, so the
# operator does not have to type it interactively. Falls back to prompting.
#
# After applying:
#   firebase deploy --only hosting
#
# Reminders:
#   - Also register the SHA-256 in Firebase Console
#     (Project Settings -> Android app -> SHA fingerprints).
#   - If you switch to Play App Signing, the SHA you must register is the
#     "App signing key certificate" SHA shown in Play Console -> Setup ->
#     App integrity, NOT the upload key. Use that one here too.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

KEYSTORE_FILE="${PROJECT_ROOT}/android/app/loadout_release.keystore"
KEY_ALIAS="loadout"
ASSETLINKS_FILE="${PROJECT_ROOT}/public/.well-known/assetlinks.json"
PACKAGE_NAME="com.johnsondigital.loadout"
APPLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --keystore)
      KEYSTORE_FILE="$2"
      shift 2
      ;;
    --alias)
      KEY_ALIAS="$2"
      shift 2
      ;;
    --assetlinks)
      ASSETLINKS_FILE="$2"
      shift 2
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if ! command -v keytool >/dev/null 2>&1; then
  echo "ERROR: 'keytool' not found on PATH. Install a JDK." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: 'python3' not found on PATH. macOS ships with python3 by default." >&2
  exit 1
fi

if [[ ! -f "${KEYSTORE_FILE}" ]]; then
  echo "ERROR: keystore not found: ${KEYSTORE_FILE}" >&2
  echo "Run scripts/generate_release_keystore.sh first." >&2
  exit 1
fi

if [[ ! -f "${ASSETLINKS_FILE}" ]]; then
  echo "ERROR: assetlinks file not found: ${ASSETLINKS_FILE}" >&2
  exit 1
fi

# Pull the storePassword from android/key.properties when available so the
# operator does not have to type it.
KEY_PROPERTIES_FILE="${PROJECT_ROOT}/android/key.properties"
STORE_PASSWORD=""
if [[ -f "${KEY_PROPERTIES_FILE}" ]]; then
  STORE_PASSWORD="$(
    awk -F= '/^[[:space:]]*storePassword[[:space:]]*=/ { sub(/^[^=]*=/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print; exit }' \
      "${KEY_PROPERTIES_FILE}"
  )"
fi

# Run keytool. If we have the password, pass it via -storepass; otherwise
# keytool will prompt.
if [[ -n "${STORE_PASSWORD}" ]]; then
  KEYTOOL_OUTPUT="$(keytool -list -v \
    -keystore "${KEYSTORE_FILE}" \
    -alias "${KEY_ALIAS}" \
    -storepass "${STORE_PASSWORD}" 2>&1)"
else
  echo "android/key.properties not found or storePassword missing."
  echo "keytool will prompt for the keystore password."
  KEYTOOL_OUTPUT="$(keytool -list -v \
    -keystore "${KEYSTORE_FILE}" \
    -alias "${KEY_ALIAS}" 2>&1)"
fi

# Extract the SHA256 line.
SHA256_LINE="$(printf '%s\n' "${KEYTOOL_OUTPUT}" | grep -E '^[[:space:]]*SHA256:[[:space:]]' | head -n1 || true)"
if [[ -z "${SHA256_LINE}" ]]; then
  echo "ERROR: could not find SHA256 fingerprint in keytool output." >&2
  echo "----- keytool output -----" >&2
  printf '%s\n' "${KEYTOOL_OUTPUT}" >&2
  echo "--------------------------" >&2
  exit 1
fi
SHA256="$(printf '%s\n' "${SHA256_LINE}" | sed -E 's/^[[:space:]]*SHA256:[[:space:]]*//')"
SHA256="$(printf '%s' "${SHA256}" | tr -d '[:space:]' | tr 'a-f' 'A-F')"

if [[ -z "${SHA256}" ]]; then
  echo "ERROR: failed to parse SHA256 fingerprint." >&2
  exit 1
fi

echo "Release keystore SHA-256:"
echo "  ${SHA256}"
echo

# Merge the SHA into assetlinks.json. We add to the FIRST entry whose
# package_name matches and whose namespace is android_app. If no such entry
# exists we append a new one.
PROPOSED_JSON="$(
  ASSETLINKS_FILE="${ASSETLINKS_FILE}" \
  PACKAGE_NAME="${PACKAGE_NAME}" \
  SHA256="${SHA256}" \
  python3 <<'PY'
import json
import os
import sys

path = os.environ["ASSETLINKS_FILE"]
package_name = os.environ["PACKAGE_NAME"]
sha = os.environ["SHA256"]

with open(path, "r") as f:
    data = json.load(f)

if not isinstance(data, list):
    print("ERROR: assetlinks.json is not a JSON array", file=sys.stderr)
    sys.exit(1)

target = None
for entry in data:
    target_obj = entry.get("target") if isinstance(entry, dict) else None
    if (
        isinstance(target_obj, dict)
        and target_obj.get("namespace") == "android_app"
        and target_obj.get("package_name") == package_name
    ):
        target = entry
        break

if target is None:
    target = {
        "relation": ["delegate_permission/common.handle_all_urls"],
        "target": {
            "namespace": "android_app",
            "package_name": package_name,
            "sha256_cert_fingerprints": [],
        },
    }
    data.append(target)

fingerprints = target["target"].setdefault("sha256_cert_fingerprints", [])
# De-dupe case-insensitively.
existing_norm = {f.replace(" ", "").upper() for f in fingerprints}
if sha.replace(" ", "").upper() not in existing_norm:
    fingerprints.append(sha)

print(json.dumps(data, indent=2))
PY
)"

echo "Proposed merged ${ASSETLINKS_FILE}:"
echo "----------------------------------------"
printf '%s\n' "${PROPOSED_JSON}"
echo "----------------------------------------"
echo

if command -v diff >/dev/null 2>&1; then
  echo "Diff vs. current file:"
  echo "----------------------------------------"
  # diff exits 1 when files differ; don't let that abort the script.
  diff -u "${ASSETLINKS_FILE}" <(printf '%s\n' "${PROPOSED_JSON}") || true
  echo "----------------------------------------"
  echo
fi

if [[ "${APPLY}" -eq 1 ]]; then
  printf '%s\n' "${PROPOSED_JSON}" > "${ASSETLINKS_FILE}"
  echo "Wrote ${ASSETLINKS_FILE}."
  echo
  echo "Next steps:"
  echo "  1. Verify the diff above is what you expected."
  echo "  2. Commit the change: git add ${ASSETLINKS_FILE#${PROJECT_ROOT}/} && git commit"
  echo "  3. Deploy: firebase deploy --only hosting"
  echo "  4. Verify it serves correctly:"
  echo "       curl -sS https://loadout-precision-reloading.web.app/.well-known/assetlinks.json"
  echo "  5. Register the SHA-256 in Firebase Console"
  echo "       (Project Settings -> Android app -> SHA fingerprints)."
else
  echo "Dry run complete. No file written."
  echo "Re-run with --apply to write the change."
fi
