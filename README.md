# Ace Mail

A fast, native IMAP/SMTP mail client written in Dart with Flutter. One codebase
for iOS, Android, macOS, Windows and Linux. Any provider, no vendor lock-in.

> No AI slop. Just code, design, and software worth using.

## Design

The interface is built on **Astryx**, Meta's open-source design system
([astryx.atmeta.com](https://astryx.atmeta.com)), rather than approximating its
look. Concretely, `lib/theme/astryx_tokens.dart` carries the real token set:

- **Type** — the geometric scale, `round(14 × 1.2^step)`, with Astryx's leading
  rule: a tiered target ratio (1.5 / 1.4 / 1.25) snapped to the 4px grid.
- **Spacing** — the 4px base-unit scale, `0 … 48px`.
- **Radius** — by role: `inner` 8, `element` 12, `container` 16, `page` 32, `full`.
- **Size** — control heights 28 / 32 / 36, with a 44px minimum pointer target.
- **Colour** — semantic tokens only (`backgroundSurface`, `textSecondary`,
  `border`, …), each with a light and a dark value. No widget reads a raw hex.

Astryx itself ships no font file; it names families and leaves loading to the
app. Its default family is Figtree, so headings use **Figtree**; body and UI
text use **Instrument Sans**. Both load through `google_fonts`. Overriding the
accent and surface ramp to the Milk & Orange brand is exactly what Astryx's
`defineTheme` is for — a custom theme, not a departure.

## Features

- Sign in to any IMAP/SMTP provider; Gmail, Outlook, Yahoo, iCloud, Zoho,
  Rediffmail, Fastmail and Proton Bridge are detected from the address, anything
  else takes manual hosts.
- Browse every folder, with unread counts.
- Read mail: HTML rendered, a plain-text toggle, and attachments listed and
  saveable.
- Compose, reply and send, with file attachments.
- Delete to Trash where the provider has one.
- Credentials live in the platform keychain, never in plain files.
- Light and dark, following the system.

## Getting it running

The Android project is included, so that target works out of the box:

```bash
git clone https://github.com/aceyash-dev/AceMail.git
cd AceMail
flutter pub get
flutter run                 # or: flutter build apk --release
```

For iOS, macOS, Windows and Linux, generate those runner projects once and copy
them in:

```bash
flutter create --org dev.acebase --project-name ace_mail \
  --platforms=ios,macos,windows,linux /tmp/ace_scaffold

cp -R /tmp/ace_scaffold/ios /tmp/ace_scaffold/macos \
      /tmp/ace_scaffold/windows /tmp/ace_scaffold/linux .
```

Doing it this way (rather than `flutter create .`) avoids overwriting
`lib/main.dart` and `pubspec.yaml`.

Linux desktop additionally needs `libsecret` for the keychain:

```bash
sudo apt install libsecret-1-dev
```

## Building the APK

Locally:

```bash
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

In CI, `.github/workflows/build.yml` runs `flutter analyze`, `flutter test` and
`flutter build apk --release` on every push and pull request, and on demand from
the Actions tab. The APK is uploaded as a build artifact; a manual run or a `v*`
tag also publishes it to a GitHub Release, so it can be downloaded without
signing in to GitHub.

## Signing in

Most providers need an **app password**, not your account password:

- **Gmail** — enable 2-Step Verification, create one at
  <https://myaccount.google.com/apppasswords>, and switch IMAP on in Gmail →
  Settings → *Forwarding and POP/IMAP*.
- **Yahoo** — Account Security → *Generate app password*.
- **iCloud** — Apple ID → *Sign-In and Security* → *App-Specific Passwords*.

Your password is stored in the platform keychain and sent only to your own mail
provider over TLS.

## Layout

```
lib/
  main.dart                 app entry
  app.dart                  MaterialApp, theme wiring
  theme/
    astryx_tokens.dart      the Astryx token set
    astryx_theme.dart       semantic type roles + ThemeData
  data/
    mail_providers.dart     IMAP/SMTP presets
    account_store.dart      keychain persistence
  models/                   account, folder, summary, full message
  services/mail_service.dart  IMAP + SMTP over enough_mail
  state/mail_controller.dart  session and screen state
  screens/                  sign-in, mailbox, compose
  widgets/                  Astryx primitives and the three panes
  util/                     date and file helpers
```

## Notes

- Mail transport is [`enough_mail`](https://pub.dev/packages/enough_mail). The
  API used here is the documented low-level `ImapClient` / `SmtpClient` surface;
  if you pin a different major version, check the few call sites in
  `mail_service.dart`.
- `flutter_html` renders message bodies. It is not a security boundary for
  hostile mail — treat HTML from untrusted senders accordingly.
