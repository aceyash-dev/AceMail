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
app. Ace Mail bundles **Questrial** and uses it for every type role. Questrial
has a single weight, so hierarchy is carried by size and colour rather than by
weight — bold text inside message bodies will not visually differ until a
weighted companion is bundled alongside it. Overriding the accent and surface
ramp to the Milk & Orange brand is exactly what Astryx's `defineTheme` is for —
a custom theme, not a departure.

## Features

- Sign in to any IMAP/SMTP provider; Gmail, Outlook, Yahoo, iCloud, Zoho,
  Rediffmail, Fastmail and Proton Bridge are detected from the address, anything
  else takes manual hosts.
- A built-in step-by-step guide — the `?` button on the sign-in screen and in
  the mailbox — covering app passwords, manual server settings, and what each
  connection error means.
- Several accounts signed in at once, switchable from the header at the top of
  the folder rail.
- The top bar shows **the folder you are in**, with search and refresh beside
  it; settings, About and help sit at the foot of the rail. The app's name is on
  the launcher and the splash, where it belongs.
- Sender pictures, best source first: the sender's own **BIMI** logo when the
  domain publishes one, then Gravatar, then an initials chip. **Off by
  default**, because both remote lookups tell a third party which domains are in
  your mail.
- Browse every folder, with unread counts, paged forty at a time. Non-selectable
  container folders such as Gmail's `[Gmail]` are filtered out.
- Search the open folder across subject and sender.
- Read mail: HTML rendered, a plain-text toggle, and attachments listed and
  saveable.
- Compose, reply and send, with file attachments.
- Mark as unread, and flag/unflag with the star.
- **One-time codes, without opening the mail.** A code in a subject is picked
  out as the row is built; for mail whose subject talks about a code but does
  not contain one, the first few kilobytes of the body are fetched and searched
  — bounded to a handful of rows per page, and never for the whole message. The
  code appears as a chip in the list, one tap from the clipboard.
- Sort chips and filters over the loaded page: newest, oldest, sender, subject
  or unread first; all, unread, flagged, or only the mail carrying a code.
- Delete moves to Trash. When a provider has no Trash folder, the app says so
  and asks before deleting permanently — it never quietly destroys mail.
- Reply and reply-all, with `In-Reply-To` and `References` set so the reply
  threads correctly in every other client.
- Swipe a message either way to act on it — archive, delete, read/unread or
  flag — with both directions configurable in settings.
- Messages open as HTML, with a per-message toggle to the plain-text version.
- Credentials live in the platform keychain, never in plain files.
- Gesture navigation: swipe right to leave a message, pull down to refresh, and
  a confirmation before the app closes.
- Light and dark, following the system.

## Getting it running

The Android project is included, so that target works out of the box:

```bash
git clone https://github.com/aceyash-dev/AceMail.git
cd AceMail
flutter pub get
flutter run                 # or: flutter build apk --release
```

### What CI verifies, and what it does not

CI runs `flutter analyze` and `flutter test` on every push and pull request, and
builds two things:

| Target | In CI | Notes |
| --- | --- | --- |
| Android (release APK) | **Yes** | arm only, signed, signer checked |
| Linux desktop | **Yes** | needs the GTK toolchain, installed by the job |
| iOS, macOS | No | need macOS runners |
| Windows | No | needs a Windows runner |

The Linux runner project is committed, so the Linux job works from a clean
checkout. The other three are not, which is why they are not claimed.

The app targets all five, but only the two above are built automatically, so
those are the two that cannot silently rot. The rest need the runner projects
generated first (below) and are built by hand.

For iOS, macOS and Windows, generate those runner projects once and copy them
in (Linux is already in the repository):

```bash
flutter create --org dev.acebase --project-name ace_mail \
  --platforms=ios,macos,windows /tmp/ace_scaffold

cp -R /tmp/ace_scaffold/ios /tmp/ace_scaffold/macos \
      /tmp/ace_scaffold/windows .
```

Doing it this way (rather than `flutter create .`) avoids overwriting
`lib/main.dart` and `pubspec.yaml`.

Linux desktop additionally needs `libsecret` for the keychain — CI installs it:

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

## Release signing

CI signs the release APK with a real keystore held in repository secrets, so
successive builds can update an installed app in place instead of demanding an
uninstall first:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the keystore, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `ace` |
| `ANDROID_KEY_PASSWORD` | the key password (same as the store password) |

`android/app/build.gradle.kts` reads `android/key.properties`, which CI writes
from those secrets. Locally, with no such file, the release build falls back to
the debug key so `flutter run --release` still works.

**Keep a copy of the keystore.** If it is lost you can never ship an update to
an installed app — Play will reject the upload and a side-load will refuse to
install over the existing one. It must never be committed: `android/.gitignore`
already excludes `*.jks`, `*.keystore` and `key.properties`.

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
  util/                     dates, file picker, HTML body renderer
assets/fonts/               Questrial-Regular.ttf
```

## Settings

Every setting changes something real and survives a restart.

| Group | Setting | Effect |
| --- | --- | --- |
| Account | Manage accounts | Add, switch or remove accounts |
| Account | Sender pictures | BIMI, then Gravatar. Off by default |
| Account | Reconnect automatically | One retry after a backoff when the connection drops |
| Reading | Mark as read when opened | Whether opening sets `\Seen` on the server |
| Reading | Message view | Formatted (HTML) or plain text |
| Reading | Messages per page | 20, 40 or 80 before "Load older messages" |
| Reading | Show one-time codes | Whether codes are picked out and shown in the list |
| Reading | Ask before deleting | A permanent delete always asks |
| Reading | Signature | Appended to new messages |
| Gestures | Swipe right | Archive, delete, read/unread, flag or nothing |
| Gestures | Swipe left | The same list, independently |
| Appearance | Theme | System, Light or Dark |
| Appearance | Text size | Multiplies the device setting |
| Appearance | List density | Comfortable or compact |
| Appearance | Ask before exiting | Whether leaving the mailbox asks first |
| Support | How to sign in | The step-by-step tutorial |
| Support | About Ace Mail | Version and what the app does with your credentials |

## Tests

```bash
flutter test
```

`test/session_test.dart` drives the session and the multi-account controller
through a `MailTransport` fake — connection de-duplication, stale-response
discarding, disposal mid-connect, delete safety with and without a Trash folder,
paging, search, flags, reply threading, the sent-copy rule, switching, removal
and serialised account mutations. `test/html_render_test.dart` covers the link
scheme policy and malformed, deeply nested and hostile markup.
`test/addresses_test.dart` covers recipient parsing and validation.
`test/sign_in_form_test.dart` covers the sign-in form model — provider lookup,
validation and account assembly — without a widget tree.
`test/models_test.dart` covers folder roles, message parsing, the Gravatar URL,
attachment filename sanitising, account JSON and date formatting.

The service layer's **policy** is extracted and tested without a server:
`test/backoff_test.dart` (the retry schedule), `test/request_queue_test.dart`
(ordering, error propagation, outstanding depth), `test/mail_errors_test.dart`
(classification by exception type and SMTP status code, plus the search
criteria), `test/attach_plan_test.dart` (which attachments fit, in bytes), and
`test/bimi_test.dart` (record parsing and the https-only rule).

What is **not** covered: the IMAP and SMTP wire paths themselves. Exercising
those needs a live or faked server, which this suite does not have — so the
fixes to the search command and the expunge target are verified by reading and
by the extracted policy around them, not by an end-to-end test. That is the
honest gap.

## Design system

A blend of Astryx (Meta) and **Material 3 Expressive** — not plain M3.

**Astryx** supplies the architecture: semantic token roles, a geometric type
scale, a 4-point spacing scale, and one `context.astryx` lookup. **Material 3
Expressive** supplies the colour, motion and shape behaviour.

- **Colour.** The palette is generated by Material's own `expressive` scheme
  variant from the brand orange, then the roles that *are* the brand — primary,
  the whole surface ramp, the outlines — are pinned back to Milk & Orange. So
  the tonal system is Material's and the identity is still the app's. Every
  Astryx role reads from that scheme; there is no parallel palette to drift.
- **Motion.** Flutter does not ship expressive motion, so it is implemented
  here: spatial springs (which settle with a little overshoot) for anything that
  moves, critically-damped effects springs for colour and opacity, and a
  deliberately under-damped `press` spring. `AceSpringy` drives them.
- **Shape.** Rounded rectangles whose corners are quarter superellipses, so the
  join between a straight edge and the curve is imperceptible. It is *not* one
  superellipse stretched over the rectangle: on a wide, short card that has no
  straight edges at all and renders as an oval. Plus a shape morph on press:
  buttons go from a stadium to a rounded rectangle, icon buttons from a circle
  to a squircle, list rows tighten their corners.
- **Components.** Pill buttons with tonal variants, an extended FAB, a floating
  pill toolbar in the reader, grouped settings sections, and a large
  collapsing app bar over the message list.
- **Loading.** Not a spinner: one form that continuously flows between shape
  families — circle, soft square, four-lobed clover, squircle — while turning
  slowly. The morph is a single continuous formula, so the surface deforms
  rather than cross-fading, and it reads as "working" at any size. Pulling the
  list down drives the same morph from the drag instead of looping it.
- **The mark.** A postbox with its flag up and a letter at the front, in the
  accent orange on a Milk tile. The letter's flap is cut *through* it rather
  than stroked, and a hairline of background separates it from the box, so it
  reads as being in front. The in-app mark, the launcher icon, the splash mark
  and the themed (monochrome) layer are one drawing at four sizes.
- **No init screen.** The keychain, the settings and the version are read before
  the first frame, so there is no blank screen on the way in. Opening the first
  mailbox shows a splash instead: the shape morph and a line that changes while
  it waits, which hands over to the mailbox rather than replacing a blank
  screen.
- **Transitions.** Material's emphasised easing, a fade-through with a 92%
  scale, predictive back on Android.

## Accessibility

- **Contrast.** Text on the accent is 4.9:1 (dark ink on the brand orange —
  white was 2.87:1 and failed AA on every filled button, badge and toggle).
  Secondary text and hints are above 5:1, disabled ink above 5:1, body text
  above 7:1. `test/contrast_test.dart` computes the ratios from the real theme
  and asserts them, in both modes, so a palette change cannot quietly regress.
- **Roles and names.** Every tap target carries a button role and an enabled
  state; icon-only controls are named by their tooltip; form fields carry their
  label, with the visible label excluded so it is not announced twice.
- **Tests.** `test/semantics_test.dart` asserts the role, the name, the enabled
  state and the tap action rather than trusting the markup.

## Hardening

Mail is hostile input, so the client treats it that way.

- **Links are restricted to `http`, `https` and `mailto`.** Everything else —
  `javascript:`, `data:`, `file:`, `intent:`, arbitrary app schemes — is dropped
  before it can reach the platform launcher, including when a scheme is
  smuggled past a naive check with control characters.
- **HTML is parsed with `package:html`**, a real parser, rather than regular
  expressions. Unclosed tags, mis-nested markup and deep nesting render
  correctly instead of producing wrong text and wrong style state. Scripts,
  styles, iframes, SVG and remote images are dropped; an image contributes only
  its alt text.
- **Size limits** cap the HTML body (2 MB), a single attachment (25 MB), the
  total decoded attachments (40 MB), attachment count (20) and outbound
  attachment total (25 MB). Oversized parts are skipped before decoding, and the
  reader says how many were left out.
- **Attachment filenames are sanitised** before being offered to the save
  dialog, so a name from a message cannot escape the chosen directory.
- **Deletion cannot lose mail.** A failed move to Trash is reported, not
  treated as "no Trash here" — a permanent delete happens only when the user
  explicitly asks for one.
- **Reading a message does not set `\Seen` as a side effect.** The flag is set
  deliberately afterwards, so a failure cannot leave the list and the server
  disagreeing.
- **Stale responses are discarded.** Folder listings, searches and message
  loads carry a request token and are dropped if a newer request has started,
  so switching quickly cannot show one folder's mail under another's name.
- **Connecting is atomic**: if the first folder listing fails, the client is
  closed and nothing is left half-open.
- **A session disposed mid-connection closes its transport** and stops
  notifying.
- **Sending distinguishes rejection from an unknown outcome.** If the
  connection drops after the server has the message, the app says delivery is
  unconfirmed and does not resend.
- **Secure-storage failures are reported**, not swallowed. A keychain that
  cannot be read, or an account that could not be saved, says so.
- **Releases fail closed.** A publishing run with no keystore secret fails
  rather than shipping a debug-signed APK, and the built APK's signer is
  checked against the expected certificate fingerprint.

## Notes

- Mail transport is [`enough_mail`](https://pub.dev/packages/enough_mail). The
  API used here is the documented low-level `ImapClient` / `SmtpClient` surface;
  if you pin a different major version, check the few call sites in
  `mail_service.dart`.
- Message bodies are rendered by `lib/util/html_render.dart`, a small
  self-contained HTML → rich-text converter: no scripts, no remote layout. It
  is not a security boundary for hostile mail — treat HTML from untrusted
  senders accordingly.
- The launcher icon is an adaptive icon — a filled orange envelope on a milk
  tile — and the in-app `BrandMark` draws the same mark from the same 108-unit
  geometry, so the two never drift apart. `AceLoader` breathes that same
  envelope wherever a spinner used to be.
- The launch window is painted in the app's own background colour with that
  mark, so the app appears to open straight onto its UI instead of flashing a
  blank screen first.
- The release manifest declares `android.permission.INTERNET`. Flutter's
  template only puts it in the debug and profile manifests, so a release build
  without it fails every connection with
  "Failed host lookup … errno = 7".
- The APK is built for `armeabi-v7a` and `arm64-v8a` only. `x86`/`x86_64` are
  emulator and ChromeOS images, and shipping them just inflates the download.
