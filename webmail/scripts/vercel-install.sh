#!/usr/bin/env bash
set -euo pipefail
bash scripts/ensure-flutter.sh
export PATH="${FLUTTER_SDK_ROOT:-$HOME/.cache/ace-flutter}/bin:$PATH"
flutter pub get
