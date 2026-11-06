#!/usr/bin/env bash
set -euo pipefail

source_path="Assets.xcassets/AppIcon.appiconset/IconSource.svg"
output_path="Assets.xcassets/AppIcon.appiconset/Icon-1024.png"

test -f "$source_path"
sips -s format png -z 1024 1024 "$source_path" --out "$output_path" >/dev/null
