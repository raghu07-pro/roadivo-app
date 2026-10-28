#!/usr/bin/env python3
"""Merge translator output (Scripts/translations/<lang>.json) into the String Catalogs as "translated".
Usage: python3 -I Scripts/merge-translations.py <lang>.json…; missing or mismatched keys are skipped."""
import json
import plistlib
import re
import sys
from collections import Counter
from pathlib import Path

SPEC = re.compile(r"%(?:\d+\$)?(lld|@|d|%)")


def specs(text):
    return Counter(SPEC.findall(text))


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def main(paths):
    catalog_path = Path("Resources/Localizable.xcstrings")
    catalog = json.loads(catalog_path.read_text())
    info = plistlib.loads(Path("Resources/Info.plist").read_bytes())
    info_keys = [
        "NSCameraUsageDescription",
        "NSLocalNetworkUsageDescription",
        "NSMicrophoneUsageDescription",
        "NSSpeechRecognitionUsageDescription",
    ]
    info_catalog = {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
    for key in info_keys:
        info_catalog["strings"][key] = {"extractionState": "manual", "localizations": {"en": unit(info[key])}}
    info_catalog["strings"]["CFBundleDisplayName"] = {
        "extractionState": "manual",
        "localizations": {"en": unit("PlayCarTV")},
    }

    problems = 0
    for path in paths:
        lang = Path(path).stem
        data = json.loads(Path(path).read_text())
        translations = data.get("localizable", {})
        for key, entry in catalog["strings"].items():
            value = translations.get(key)
            if value is None or not value.strip():
                print(f"[{lang}] missing: {key!r}")
                problems += 1
                continue
            if specs(value) != specs(key):
                print(f"[{lang}] format mismatch: {key!r} -> {value!r}")
                problems += 1
                continue
            entry.setdefault("localizations", {})[lang] = unit(value)
        for key in info_keys:
            value = data.get("infoPlist", {}).get(key)
            if value:
                info_catalog["strings"][key]["localizations"][lang] = unit(value)
        info_catalog["strings"]["CFBundleDisplayName"]["localizations"][lang] = unit("PlayCarTV")

    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    Path("Resources/InfoPlist.xcstrings").write_text(
        json.dumps(info_catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    )
    print(f"Merged {len(paths)} languages; {problems} problems.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
