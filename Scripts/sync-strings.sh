#!/usr/bin/env bash
# Syncs Resources/Localizable.xcstrings with the strings the code uses (.stringsdata + xcstringstool).
# Usage: Scripts/sync-strings.sh [<derived-data path>] (without one, builds into a temp folder first).
set -euo pipefail

cd "$(dirname "$0")/.."

CATALOG="Resources/Localizable.xcstrings"
DERIVED="${1:-}"

if [[ -z "$DERIVED" ]]; then
  DERIVED="$(mktemp -d -t playcartv-strings)"
  echo "Building PlayCarTV for the simulator into $DERIVED …"
  xcodebuild \
    -workspace PlayCarTV.xcworkspace \
    -scheme PlayCarTV \
    -configuration Debug \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$DERIVED" \
    build >/dev/null
fi

OBJECTS="$DERIVED/Build/Intermediates.noindex/PlayCarTV.build/Debug-iphonesimulator/PlayCarTV.build/Objects-normal"
if [[ ! -d "$OBJECTS" ]]; then
  echo "No PlayCarTV build in $DERIVED (looked for $OBJECTS)." >&2
  exit 1
fi

# Only the files whose source still exists: DerivedData keeps a deleted
# file's .stringsdata, and its strings would come back into the catalog.
STRINGSDATA=()
while IFS= read -r -d '' file; do
  source="$(plutil -extract source raw -o - "$file")"
  if [[ -f "$source" ]]; then
    STRINGSDATA+=("$file")
  fi
done < <(find "$OBJECTS" -name '*.stringsdata' -print0)

if [[ ${#STRINGSDATA[@]} -eq 0 ]]; then
  echo "No .stringsdata in $OBJECTS — is SWIFT_EMIT_LOC_STRINGS on?" >&2
  exit 1
fi

xcrun xcstringstool sync "$CATALOG" --stringsdata "${STRINGSDATA[@]}"
echo "Synced $CATALOG from ${#STRINGSDATA[@]} source files."
echo "New keys have no comment yet: give each one for its translators."
