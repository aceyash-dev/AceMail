#!/usr/bin/env python3
"""Applies Ace Mail's iOS configuration to a freshly generated ios/ runner.

Run by tool/ios/setup_ios.sh right after `flutter create` has produced the
runner. Everything Ace Mail needs on iOS that Flutter does not generate is set
here, in one place, so it is reviewable and repeatable:

* Info.plist: the permission strings the features ask for, the background
  task that runs the mail check, and the Google client for sign-in.
* AppDelegate.swift: the plugin registrant for the background isolate, and
  the voice channel the mailbox's microphone uses.
* project.pbxproj: the bundle identifier, which must match Android's
  application ID (app.tab.mail), not the one flutter create derives.

It fails loudly when the generated files are not the shape it expects. A
silent partial patch would build, and then fail on a device.

Environment:
  IOS_GOOGLE_CLIENT_ID  The iOS OAuth client ID from Google Cloud. Optional
                        for a build that does not sign in with Google, but
                        Gmail cannot sign in without it.
"""

from __future__ import annotations

import os
import plistlib
import re
import sys
from pathlib import Path

BUNDLE_ID = "app.tab.mail"
MAIL_CHECK_TASK = "app.tab.mail.check"  # Must equal kMailCheckTask in Dart.
VOICE_SNIPPET = Path(__file__).with_name("AceVoiceChannel.swift.snippet")


def fail(message: str) -> None:
    print(f"configure_ios: {message}", file=sys.stderr)
    sys.exit(1)


def configure_info_plist(runner: Path, client_id: str | None) -> None:
    path = runner / "Info.plist"
    with path.open("rb") as handle:
        plist = plistlib.load(handle)

    # Why each string exists. iOS shows these to the person, so they say what
    # the app does with the permission and nothing more.
    plist["NSFaceIDUsageDescription"] = (
        "Unlock Ace Mail with Face ID when you turn on the app lock."
    )
    plist["NSMicrophoneUsageDescription"] = (
        "Ace Mail listens only when you tap the microphone in the search bar."
    )
    plist["NSSpeechRecognitionUsageDescription"] = (
        "Ace Mail turns the words you say into text for the search bar."
    )

    # Saved attachments live in the documents folder, and these two keys are
    # what make that folder show up in the Files app, under "Ace Mail".
    plist["UIFileSharingEnabled"] = True
    plist["LSSupportsOpeningDocumentsInPlace"] = True

    # The mail check runs as a BGTask. The identifier has to be the Dart task
    # name exactly, or iOS refuses to schedule it.
    plist["UIBackgroundModes"] = sorted(set(plist.get("UIBackgroundModes", []) + ["fetch"]))
    plist["BGTaskSchedulerPermittedIdentifiers"] = [MAIL_CHECK_TASK]

    if client_id:
        plist["GIDClientID"] = client_id
        # google_sign_in returns to the app on a URL built from the client ID,
        # reversed: com.googleusercontent.apps.<the part before .apps.>.
        prefix = client_id.split(".apps.googleusercontent.com")[0]
        reversed_scheme = f"com.googleusercontent.apps.{prefix}"
        url_types = [
            t for t in plist.get("CFBundleURLTypes", [])
            if t.get("CFBundleURLName") != "google-sign-in"
        ]
        url_types.append({
            "CFBundleURLName": "google-sign-in",
            "CFBundleURLSchemes": [reversed_scheme],
        })
        plist["CFBundleURLTypes"] = url_types
    else:
        print(
            "configure_ios: IOS_GOOGLE_CLIENT_ID is not set. The app builds, "
            "but Google sign-in on iOS will not work until it is.",
            file=sys.stderr,
        )

    with path.open("wb") as handle:
        plistlib.dump(plist, handle)


def configure_app_delegate(runner: Path) -> None:
    path = runner / "AppDelegate.swift"
    source = path.read_text()

    # Flutter 3.41+ uses UIScene and registers plugins from
    # didInitializeImplicitFlutterEngine. Older templates register them in
    # application(_:didFinishLaunchingWithOptions:). Support both forms.
    legacy_registrant = "GeneratedPluginRegistrant.register(with: self)" in source
    modern_registrant = (
        "GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)"
        in source
    )
    if not legacy_registrant and not modern_registrant:
        fail(
            "AppDelegate.swift has no recognized GeneratedPluginRegistrant "
            "call (legacy or FlutterImplicitEngineDelegate)."
        )
    if "import UIKit" not in source:
        fail("AppDelegate.swift has no `import UIKit` to anchor the imports to.")
    if "return super.application(" not in source:
        fail("AppDelegate.swift has no `return super.application(` to anchor the configuration to.")
    if "app.tab.mail/voice" in source:
        return  # Already configured; the script is safe to run twice.

    source = source.replace(
        "import UIKit",
        "import AVFoundation\nimport Speech\nimport UIKit\nimport workmanager_apple",
        1,
    )

    if legacy_registrant:
        # Legacy Flutter template: configure the background isolate and native
        # channel in application(_:didFinishLaunchingWithOptions:).
        wiring = (
            "    // The background mail check runs in its own engine, which needs the\n"
            "    // same plugins as this one.\n"
            "    WorkmanagerPlugin.setPluginRegistrantCallback { registry in\n"
            "      GeneratedPluginRegistrant.register(with: registry)\n"
            "    }\n"
            "    aceVoiceChannel = AceVoiceChannel(\n"
            "      messenger: self.registrar(forPlugin: \"AceVoice\")!.messenger()\n"
            "    )\n\n"
        )
        source = source.replace(
            "    return super.application(", wiring + "    return super.application(", 1
        )
    else:
        if "FlutterImplicitEngineDelegate" not in source:
            fail(
                "AppDelegate.swift uses the implicit-engine plugin registry but "
                "does not conform to FlutterImplicitEngineDelegate."
            )
        # Modern Flutter template: both plugin registration and channel
        # creation must use the implicit engine's registry/messenger. The
        # app delegate's registrar is not the right engine under UIScene.
        registration = (
            "    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)\n"
        )
        wiring = (
            "    // The background mail check runs in its own engine, which needs the\n"
            "    // same plugins as this one.\n"
            "    WorkmanagerPlugin.setPluginRegistrantCallback { registry in\n"
            "      GeneratedPluginRegistrant.register(with: registry)\n"
            "    }\n"
            "    aceVoiceChannel = AceVoiceChannel(\n"
            "      messenger: engineBridge.applicationRegistrar.messenger()\n"
            "    )\n"
        )
        if registration not in source:
            fail(
                "AppDelegate.swift has an implicit-engine delegate but its plugin "
                "registrant call is not in the expected form."
            )
        source = source.replace(registration, registration + wiring, 1)

    source = source.rstrip() + "\n\n" + VOICE_SNIPPET.read_text()
    path.write_text(source)


def configure_bundle_id(runner: Path) -> None:
    """Sets the app's bundle ID to Android's, and keeps the test target's suffix."""
    pbxproj = runner.parent / "Runner.xcodeproj" / "project.pbxproj"
    text = pbxproj.read_text()

    def replace(match: re.Match[str]) -> str:
        value = match.group(1)
        suffix = ".RunnerTests" if value.endswith(".RunnerTests") else ""
        return f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}{suffix};"

    updated, count = re.subn(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", replace, text)
    if count == 0:
        fail("project.pbxproj has no PRODUCT_BUNDLE_IDENTIFIER to set.")
    pbxproj.write_text(updated)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: configure_ios.py <path to ios/>")
    runner = Path(sys.argv[1]) / "Runner"
    if not (runner / "Info.plist").exists():
        fail(f"no Runner/Info.plist under {sys.argv[1]}")

    client_id = os.environ.get("IOS_GOOGLE_CLIENT_ID", "").strip() or None
    configure_info_plist(runner, client_id)
    configure_app_delegate(runner)
    configure_bundle_id(runner)
    print("configure_ios: Info.plist, AppDelegate.swift and the bundle ID are set.")


if __name__ == "__main__":
    main()
