#!/usr/bin/env bash
# Generates the Windows and macOS runners, the way tool/ios/setup_ios.sh does.
#
# Neither folder is committed. They are Flutter's own template with a handful of
# settings applied, and a template that lives in the repository is a template
# nobody updates — it silently rots against each Flutter release while the phone
# builds keep moving. Generating them here means a change that breaks the
# desktop configuration fails this job instead of shipping.
set -euo pipefail

here="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$here"

platforms="${1:-windows,macos}"

echo "Generating: $platforms"
# --platforms leaves the existing android/ and linux/ runners alone.
flutter create --platforms="$platforms" --project-name ace_mail . >/dev/null

# --- macOS ----------------------------------------------------------------
# The app talks to IMAP and SMTP directly, so it needs the network client
# entitlement. Without it a sandboxed build connects to nothing and every
# mailbox fails in a way that looks like a password problem.
for f in macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements; do
  [ -f "$f" ] || continue
  /usr/libexec/PlistBuddy -c "Add :com.apple.security.network.client bool true" "$f" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :com.apple.security.network.client true" "$f"
done

# A minimum window size, so the first launch is not a 320pt column with the
# rail and the list fighting over it.
main="macos/Runner/MainFlutterWindow.swift"
if [ -f "$main" ] && ! grep -q "AceMailMinSize" "$main"; then
  python3 - "$main" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace(
    "self.window?.setFrame(frame, display: true)",
    "self.window?.setFrame(frame, display: true)\n"
    "    // AceMailMinSize: below this the rail and the list cannot both be read.\n"
    "    self.window?.minSize = NSSize(width: 900, height: 620)",
    1,
)
open(p, 'w').write(s)
PY
fi

# --- Windows --------------------------------------------------------------
# local_auth_windows includes <experimental/coroutine>, which MSVC 18 (the
# Visual Studio 2026 image) turned from a warning into a hard error. The error
# names its own escape hatch; this sets it for the whole build, because the
# header is pulled in by a plugin and not by anything in this repository.
win_cmake="windows/CMakeLists.txt"
if [ -f "$win_cmake" ] && ! grep -q "_SILENCE_EXPERIMENTAL_COROUTINE" "$win_cmake"; then
  python3 - "$win_cmake" <<'PYW'
import sys
p = sys.argv[1]
s = open(p).read()
marker = "project(ace_mail LANGUAGES CXX)"
if marker in s:
    s = s.replace(
        marker,
        marker + "\n\n"
        "# local_auth_windows pulls in <experimental/coroutine>, which MSVC 18\n"
        "# rejects outright. Superseded by <coroutine>, but not by us.\n"
        "add_compile_definitions(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)",
        1,
    )
    open(p, 'w').write(s)
PYW
fi

# The default window title is the project name; the app has a name.
win="windows/runner/main.cpp"
if [ -f "$win" ]; then
  sed -i 's/L"ace_mail"/L"Ace Mail"/' "$win" 2>/dev/null || true
  python3 - "$win" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"Win32Window::Size size\(\d+, \d+\);",
           "// Wide enough for the rail and the list side by side.\n"
           "  Win32Window::Size size(1180, 760);", s, count=1)
open(p, 'w').write(s)
PY
fi

echo "Desktop runners ready."
