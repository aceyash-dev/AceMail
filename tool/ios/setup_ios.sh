#!/usr/bin/env bash
# Generates Ace Mail's iOS runner and applies its configuration.
#
# Run on a Mac with Xcode, from the repository root:
#
#   IOS_GOOGLE_CLIENT_ID=<your iOS client ID> tool/ios/setup_ios.sh
#
# This creates ios/ from Flutter's own template, then applies what Ace Mail
# needs on top (tool/ios/configure_ios.py). The result is committed, so the
# iOS project is reviewed like any other source rather than regenerated
# silently. CI runs the same script on a macOS runner and builds the app, so a
# change that breaks the iOS build is caught before it lands.
set -euo pipefail

cd "$(dirname "$0")/../.."

if [ -d ios/Runner.xcodeproj ] && [ "${FORCE:-}" != "1" ]; then
  echo "ios/ already exists. Set FORCE=1 to regenerate it from scratch." >&2
  exit 1
fi

scaffold="$(mktemp -d)"
trap 'rm -rf "$scaffold"' EXIT

# Only the iOS platform, into a scratch directory, so that flutter create
# cannot overwrite lib/main.dart or pubspec.yaml.
flutter create --org app.tab --project-name ace_mail --platforms=ios "$scaffold/project" >/dev/null

rm -rf ios
cp -R "$scaffold/project/ios" ios

python3 tool/ios/configure_ios.py ios

echo "iOS runner ready. Build it with: flutter build ios --no-codesign"
