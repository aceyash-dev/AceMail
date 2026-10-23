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
app. Ace Mail bundles **Geograph** and uses it for every type role. Geograph
has a single weight, so hierarchy is carried by size and colour rather than by
weight — bold text inside message bodies will not visually differ until a
weighted companion is bundled alongside it. Overriding the accent and surface
ramp to the Milk & Orange brand is exactly what Astryx's `defineTheme` is for —
a custom theme, not a departure.

## Features

- Sign in to any IMAP/SMTP provider. Gmail, Yahoo, iCloud, Zoho, GMX and Yandex
  are detected from the address; anything else takes manual hosts. **Gmail signs
  in with Google** — no password, and nothing stored; the rest use an **app
  password**. The built-in list is deliberately short — every entry works
  **free**, over IMAP/SMTP. Providers that need OAuth this app does not
  implement (Outlook), a paid bridge (Proton), a paid plan (Fastmail, and
  Rediffmail whose IMAP is Pro-only), or that have dropped free IMAP for new
  accounts (Zoho), are not offered: a provider that cannot work is a dead end
  the user only finds after typing a password.
- A built-in step-by-step guide — the `?` button on the sign-in screen and in
  the mailbox — covering app passwords, manual server settings, and what each
  connection error means.
- Several accounts signed in at once, switchable from the header at the top of
  the folder rail.
- The top bar is the **search bar** — with voice search beside it, and Sort &
  filter and Chyme next to that. The folder you are in, and what is waiting in
  it, is the greeting above the list, which is where a person looks anyway.
  Settings, About and help sit at the foot of the rail; the app's name is on the
  launcher and the splash, where it belongs.
- **Pull down to refresh** — the indicator is the shape morph, scrubbed by the
  drag, so a pull walks it through the families. Ctrl/Cmd+R does the same from a
  keyboard. There is no refresh button in the top bar. The list uses bouncing
  physics on every platform, because Android's default physics *clamps*: a
  clamped list never overscrolls, so the refresh control never fires.
- **Ten accents, and the theme is global.** Material's palette, one step in
  from the primaries. Each is walked along its own lightness until a label on
  it clears AA *and* the shape reads against the page — blue at full strength is
  3.7:1 against white and 4.4:1 against ink, and amber is 1.75:1 against Milk,
  so neither is usable as-is. The swatch shows the colour you picked; the fill
  is made legible. Every surface is then the accent-tinted Milk or Ink, so
  changing the accent changes the page and not just the buttons. Material's own
  tonal palette desaturates surfaces almost to grey, which is why they are
  tinted by hand. `test/contrast_test.dart` checks all ten accents in both
  modes, over the tinted surfaces.
- **Images in a message are placeholders** until you ask for them, and the
  switch works on the message that is open rather than the next one. Sources
  are resolved, so a protocol-relative `//cdn.example/logo.png` — which most
  mail with a CDN uses — loads too. A 1×1 tracking pixel is dropped entirely
  rather than becoming a placeholder in the middle of a message that has no
  images in it. Fetching a
  remote image tells the sender's server the mail was opened, so it is off by
  default and a switch in Settings turns it on. Either way the placeholder takes
  the image's place rather than a bracket of alt text landing mid-sentence.
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
builds these targets:

| Target | In CI | Notes |
| --- | --- | --- |
| Android (release APK) | **Yes** | arm only, signed, signer checked |
| Linux desktop | **Yes** | GTK and libsecret installed by the job |
| iOS (unsigned) | **Yes** | macOS runner; the runner is generated by `tool/ios/setup_ios.sh` |
| macOS, Windows | No | need their runner projects generated first (below) |

The Android and Linux projects are committed. The iOS project is generated by
`tool/ios/setup_ios.sh` from Flutter's own template, with Ace Mail's
configuration applied on top, so it can be regenerated and reviewed.

### iOS

Needs a Mac with Xcode. Run once from the repository root:

```bash
IOS_GOOGLE_CLIENT_ID=<your iOS OAuth client ID> tool/ios/setup_ios.sh
flutter build ios --no-codesign --debug
```

The script writes `ios/` and sets what Ace Mail needs on it: the permission
strings (Face ID, microphone, speech), the background mail check (its identifier
must equal the Dart task name), the Google client for sign-in, and the bundle
identifier, which matches Android's `app.tab.mail`. Commit the generated `ios/`
so later changes are reviewed as ordinary source.

Two iOS differences from Android, both on purpose:

* **Voice search asks for the microphone.** iOS runs speech recognition inside
  the app, so it needs the microphone and speech permissions that Android's
  design avoids. The first tap asks, and the answer is the person's to give.
* **Background checks are the system's to schedule.** iOS decides when the
  mail check runs, so it can come later than fifteen minutes.

Signing and distribution need an Apple developer account and are not set up.

### Linux

The Linux project is committed and built in CI. Linux has no `google_sign_in`,
so Gmail on Linux signs in through the browser instead. That needs a **Desktop**
OAuth client from the same Google Cloud project, passed at build time:

```bash
flutter run -d linux \
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID=... \
  --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...
```

Unlike Android and iOS, the desktop sign-in keeps a refresh token, so the person
is not sent back to the browser every hour. It is stored in the system keychain
(libsecret), beside the passwords for the other providers, and never in a plain
file. Without the two defines the app builds and says Gmail is not configured
on this build.

Linux desktop needs `libsecret` for the keychain:

```bash
sudo apt install libsecret-1-dev
```

### macOS and Windows

Their runner projects are not committed or built in CI. Generate them once and
copy them in:

```bash
flutter create --org app.tab --project-name ace_mail \
  --platforms=macos,windows /tmp/ace_scaffold

cp -R /tmp/ace_scaffold/macos /tmp/ace_scaffold/windows .
```

Doing it this way (rather than `flutter create .`) avoids overwriting
`lib/main.dart` and `pubspec.yaml`.

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

**Gmail signs in with Google.** Gmail stopped accepting app passwords for IMAP
and SMTP in 2022, so the sign-in screen offers *Continue with Google* instead of
a password field, and the mailbox is reached with an OAuth access token (SASL
XOAUTH2). Nothing is stored as a result: no password, no refresh token. The
token lives about an hour and a new one is fetched when a connection needs it.

Setting that up needs four things in the Google Cloud project. This is the part
that has to be right, because every failure here looks like a generic sign-in
error:

1. **An Android OAuth client**, registered against the package name and the
   signing certificate:

   | Field | Value |
   | --- | --- |
   | Package name | `app.tab.mail` |
   | Release SHA-1 | `92:0B:5F:51:DC:85:E2:D8:2F:97:21:F5:3A:D6:5C:1A:E4:5E:0D:4C` |
   | Debug SHA-1 | from `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android` |

   One client can carry several SHA-1s. Register the debug one too, or local
   builds will sign in and release builds will not — the plugin's README lists
   that as the most common cause of a confusing failure.

2. **A web OAuth client**, in the same project. Its ID is what Android's
   Credential Manager wants as `serverClientId`, and it is the one in
   `GoogleAuth.clientId`:

   ```
   919591212641-i8ugliojp1j16esai9jh3f5e5foiucoj.apps.googleusercontent.com
   ```

   If that ID turns out to be an *Android* client rather than a web one, create
   a web client and replace the constant — the value has to be a web client ID.

3. **The Gmail API enabled** for the project, at
   <https://console.cloud.google.com/apis/library/gmail.googleapis.com>.

4. **The consent screen** listing the scope, which is the full-access one:

   ```
   https://mail.google.com/
   ```

   There is no narrower grant that lets a client read *and* send over IMAP and
   SMTP, so this is a restricted scope. While the app is unverified, the project
   has to be in *Testing* and every account that signs in has to be added as a
   **test user** — otherwise Google refuses with `access_denied` no matter how
   correct the rest is.

`clientConfigurationError` means 1 or 2; `providerConfigurationError` means 3
or 4. The app says which, in those words.

Everything else needs an **app password**, not your account password:

- **Yahoo** — Account Security → *Generate app password*.
- **Yahoo** — Account Security → *Generate app password*.
- **iCloud** — Apple ID → *Sign-In and Security* → *App-Specific Passwords*.
- **Zoho** — Security → *App Passwords*, and switch IMAP on under *Mail
  Accounts*. (Existing free accounts only; Zoho no longer grants IMAP to new
  free users.)
- **GMX** — Security Options → *Manage application-specific passwords*, and
  enable POP3/IMAP under Email → Settings.
- **Yandex** — Yandex ID → *App passwords* → *Mail*, and enable IMAP under
  Email clients.

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
assets/fonts/               Geograph-Regular.ttf
```

## Settings

Every setting changes something real and survives a restart.

| Group | Setting | Effect |
| --- | --- | --- |
| Account | Manage accounts | Add, switch or remove accounts |
| Account | Sender pictures | Gravatar. Off by default — BIMI needs no switch |
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
| Appearance | Accent | Ten Material accents, each checked for contrast |
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
- **The mark.** A postbox with its flag up and a letter at the front, drawn as
  an outline on a Milk tile: a grey back where the box opens, a ground line,
  speed lines, and the flag as the one filled, accented part. The accent means
  something because it is the only thing wearing it. A hairline of background
  separates the letter from the box, so it reads as being in front. The in-app
  mark, the launcher icon, the splash mark and the themed (monochrome) layer are
  one drawing at four sizes.
- **The loading indicator** is a real Material shape morph. Each shape family is
  a radial profile — the distance from the centre at 128 angles — and morphing
  interpolates every one of those points, so the shape passes through the
  intermediate forms instead of one formula being tuned towards another. It
  holds each shape briefly before travelling, because a morph that never rests
  is a blob. `test/shape_morph_test.dart` asserts the profiles, the family
  geometry and the continuity of the cycle.
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
