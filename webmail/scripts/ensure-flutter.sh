#!/usr/bin/env bash
set -euo pipefail

if command -v flutter >/dev/null 2>&1; then
  flutter --version
  exit 0
fi

SDK_ROOT="${FLUTTER_SDK_ROOT:-$HOME/.cache/ace-flutter}"
if [ -x "$SDK_ROOT/bin/flutter" ]; then
  export PATH="$SDK_ROOT/bin:$PATH"
  flutter --version
  exit 0
fi

mkdir -p "$(dirname "$SDK_ROOT")"
RELEASES_JSON="$(mktemp)"
trap 'rm -f "$RELEASES_JSON"' EXIT
curl --fail --location --retry 3 --silent --show-error \
  https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json \
  -o "$RELEASES_JSON"
ARCHIVE="$(python3 - "$RELEASES_JSON" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
version = data["current_release"]["stable"]
release = next(item for item in data["releases"] if item["version"] == version and item["channel"] == "stable")
print("https://storage.googleapis.com/flutter_infra_release/releases/" + release["archive"])
PY
)"
mkdir -p "$SDK_ROOT"
curl --fail --location --retry 3 --silent --show-error "$ARCHIVE" | tar -xJ -C "$SDK_ROOT" --strip-components=1
export PATH="$SDK_ROOT/bin:$PATH"
flutter --version
