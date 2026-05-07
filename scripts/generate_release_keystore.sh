#!/usr/bin/env bash
# Generates a release keystore for LoadOut.
# Usage: ./scripts/generate_release_keystore.sh
# Will prompt for key password and store password (interactively, via keytool).
# Output: android/app/loadout_release.keystore
#
# DO NOT COMMIT THE KEYSTORE OR PASSWORDS TO VCS.
#   - android/app/*.keystore is .gitignore'd
#   - android/key.properties is .gitignore'd
#
# After running this script:
#   1. Copy android/key.properties.example to android/key.properties
#   2. Fill in the storePassword and keyPassword you chose below
#   3. Build with: flutter build apk --release  (or appbundle)
#   4. Extract the SHA-256 fingerprint with:
#        keytool -list -v \
#          -keystore android/app/loadout_release.keystore \
#          -alias loadout
#   5. Add the SHA-256 to:
#        - Firebase Console -> Project Settings -> Android app -> SHA fingerprints
#        - public/.well-known/assetlinks.json (run scripts/update_assetlinks.sh)
#      Then redeploy hosting: firebase deploy --only hosting
#
# Back up the keystore + key.properties somewhere safe (1Password, encrypted
# external drive, etc.). If you lose the keystore you cannot publish updates
# to the same Play Store listing under the same upload key — you will have to
# go through Play's lost-key recovery flow.

set -euo pipefail

# Resolve project root (parent of this script's directory).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

KEYSTORE_DIR="${PROJECT_ROOT}/android/app"
KEYSTORE_FILE="${KEYSTORE_DIR}/loadout_release.keystore"
KEY_ALIAS="loadout"

# 25 years validity. Play Store requires the upload key to be valid through
# at least Oct 2033, so 25 years is comfortable.
VALIDITY_DAYS=9125

# Distinguished Name for the certificate. These don't need to match anything
# real to a Play user — Google verifies the certificate by fingerprint, not
# by DN — but they're embedded in the cert and should be sane.
DNAME="CN=LoadOut, OU=Mobile, O=Johnson Digital Systems, L=Unknown, ST=Unknown, C=US"

if ! command -v keytool >/dev/null 2>&1; then
  echo "ERROR: 'keytool' not found on PATH." >&2
  echo "Install a JDK (JDK 17 recommended; matches the project compileOptions)." >&2
  echo "On macOS: brew install --cask temurin@17" >&2
  exit 1
fi

mkdir -p "${KEYSTORE_DIR}"

if [[ -e "${KEYSTORE_FILE}" ]]; then
  echo "ERROR: ${KEYSTORE_FILE} already exists." >&2
  echo "Refusing to overwrite. If you really want to replace it, move/remove" >&2
  echo "the existing file first. Be aware that replacing the upload key on a" >&2
  echo "published Play Store listing requires Google support intervention." >&2
  exit 1
fi

echo "Generating release keystore at:"
echo "  ${KEYSTORE_FILE}"
echo
echo "You will be prompted twice:"
echo "  1) Keystore password (storePassword)"
echo "  2) Key password         (keyPassword)"
echo
echo "Use a strong, unique password for each. Store both in your password"
echo "manager. You will need them in android/key.properties before you can"
echo "build a release APK / App Bundle."
echo

keytool \
  -genkeypair \
  -v \
  -keystore "${KEYSTORE_FILE}" \
  -alias "${KEY_ALIAS}" \
  -keyalg RSA \
  -keysize 2048 \
  -validity "${VALIDITY_DAYS}" \
  -dname "${DNAME}"

echo
echo "Done."
echo
echo "Next steps:"
echo "  1. cp android/key.properties.example android/key.properties"
echo "  2. Edit android/key.properties and fill in storePassword + keyPassword."
echo "  3. flutter build appbundle --release   # or apk --release"
echo "  4. Extract the SHA-256 fingerprint and register it:"
echo "       keytool -list -v -keystore '${KEYSTORE_FILE}' -alias '${KEY_ALIAS}'"
echo "     - Add it to Firebase Console (Project Settings -> Android app -> SHA fingerprints)"
echo "     - Run scripts/update_assetlinks.sh to add it to assetlinks.json"
echo "     - Redeploy hosting: firebase deploy --only hosting"
echo
echo "Back up '${KEYSTORE_FILE}' and your passwords now. Losing them is"
echo "expensive to recover from."
