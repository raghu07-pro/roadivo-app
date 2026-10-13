#!/usr/bin/env bash
# Sync Resources/Localizable.xcstrings with the strings the app's code uses.
#
# The catalog is extracted, never hand-typed. With SWIFT_EMIT_LOC_STRINGS on
# (Project.swift), the compiler writes every localizable literal it compiles —
# `Text("…")`, `String(localized:)`, `LocalizedStringResource` — to a
# `.stringsdata` file, keyed with the format specifier each interpolation
# needs (`%lld` for an Int, `%@` for a String). `xcstringstool sync` merges
# those into the catalog: new keys are added, keys the code no longer uses are
# removed (or marked stale, if they carry translations), and existing comments
# and translations are kept.
#
#
# Usage: Scripts/sync-strings.sh [<derived-data path>]
#   With a path, uses the .stringsdata a Debug simulator build of the Roadivo
#   target already left there. Without one, builds the app into a temporary
#   directory first (no simulator needed).
set -euo pipefail

cd "$(dirname "$0")/.."

CATALOG="Resources/Localizable.xcstrings"
DERIVED="${1:-}"

if [[ -z "$DERIVED" ]]; then
  DERIVED="$(mktemp -d -t roadivo-strings)"
  echo "Building Roadivo for the simulator into $DERIVED …"
  xcodebuild \
    -workspace Roadivo.xcworkspace \
    -scheme Roadivo \
    -configuration Debug \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$DERIVED" \
    build >/dev/null
fi

OBJECTS="$DERIVED/Build/Intermediates.noindex/Roadivo.build/Debug-iphonesimulator/Roadivo.build/Objects-normal"
if [[ ! -d "$OBJECTS" ]]; then
  echo "No Roadivo build in $DERIVED (looked for $OBJECTS)." >&2
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
