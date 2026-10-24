#!/usr/bin/env bash
set -euo pipefail
bash scripts/ensure-flutter.sh
export PATH="${FLUTTER_SDK_ROOT:-$HOME/.cache/ace-flutter}/bin:$PATH"
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter build web --release \
  --dart-define=GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-}" \
  --dart-define=ACEMAIL_API_BASE_URL="${ACEMAIL_API_BASE_URL:-}"
