#!/bin/bash
# Re-captures Screenshots/review from the UI tests: every numbered snapshot("NN-Name") they take.
# Usage: Scripts/export-review-screenshots.sh ["iPhone 16e"]   (DERIVED_DATA overrides the build folder)
set -euo pipefail
cd "$(dirname "$0")/.."

device="${1:-iPhone 17 Pro}"
derived="${DERIVED_DATA:-.build/DerivedData}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

xcodebuild -workspace Roadivo.xcworkspace -scheme Roadivo \
  -destination "platform=iOS Simulator,name=$device" \
  -derivedDataPath "$derived" -resultBundlePath "$work/run.xcresult" \
  test -only-testing:RoadivoUITests > "$work/test.log" 2>&1 ||
  echo "Some UI tests failed (see the run's log); exporting the screens that were captured."

xcrun xcresulttool export attachments --path "$work/run.xcresult" --output-path "$work/attachments" > /dev/null

python3 -I - "$work/attachments" Screenshots/review << 'EOF'
import json, re, shutil, sys
from pathlib import Path

source, target = Path(sys.argv[1]), Path(sys.argv[2])
target.mkdir(parents=True, exist_ok=True)
chosen = {}
for test in json.loads((source / "manifest.json").read_text()):
    # ScreenshotUITests is the canonical walk-through; other tests only fill gaps.
    rank = 0 if "ScreenshotUITests" in test.get("testIdentifier", "") else 1
    for item in test.get("attachments", []):
        match = re.match(r"^(\d\d[a-z]?-[^_]+)_\d+_[0-9A-F-]+\.png$", item.get("suggestedHumanReadableName", ""))
        if match and (match[1] not in chosen or rank < chosen[match[1]][0]):
            chosen[match[1]] = (rank, source / item["exportedFileName"])
for name, (_, file) in sorted(chosen.items()):
    shutil.copyfile(file, target / f"{name}.png")
print(f"Updated {len(chosen)} screenshots in {target}")
EOF
