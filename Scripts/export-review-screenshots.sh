#!/bin/bash
# Re-captures Screenshots/review from the UI tests: every numbered snapshot("NN-Name") they take.
# Usage: Scripts/export-review-screenshots.sh ["iPhone 16e"]   (DERIVED_DATA overrides the build folder)
# OUT and ONLY pick another folder and test list, e.g. App Store sizes:
#   OUT=Screenshots/AppStore/6.9 ONLY=RoadivoUITests/ScreenshotUITests Scripts/export-review-screenshots.sh "iPhone 17 Pro Max"
# WORKERS simulator clones run the tests side by side (3 by default; 1 for one at a time). No code coverage, and a test
# stuck past 10 minutes fails instead of holding up the run (the longest screenshot walks take over 3). The log stays in .build/ui-tests.log.
set -euo pipefail
cd "$(dirname "$0")/.."

device="${1:-iPhone 17 Pro}"
derived="${DERIVED_DATA:-.build/DerivedData}"
target="${OUT:-Screenshots/review}"
only="${ONLY:-RoadivoUITests}"
workers="${WORKERS:-3}"
work="$(mktemp -d)"
trap 'cp "$work/test.log" .build/ui-tests.log 2>/dev/null || true; rm -rf "$work"' EXIT

xcodebuild -workspace Roadivo.xcworkspace -scheme Roadivo \
  -destination "platform=iOS Simulator,name=$device" \
  -derivedDataPath "$derived" -resultBundlePath "$work/run.xcresult" \
  -parallel-testing-enabled YES -parallel-testing-worker-count "$workers" \
  -enableCodeCoverage NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 900 \
  test -only-testing:"$only" > "$work/test.log" 2>&1 || {
  echo "Some UI tests failed; exporting the screens that were captured. Failures:"
  grep -E "error: -\[" "$work/test.log" | sed 's|.*error: ||' | sort -u || true
}
grep -E "Executed [0-9]+ tests?, with" "$work/test.log" | tail -1 || true

xcrun xcresulttool export attachments --path "$work/run.xcresult" --output-path "$work/attachments" > /dev/null

python3 -I - "$work/attachments" "$target" << 'EOF'
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
