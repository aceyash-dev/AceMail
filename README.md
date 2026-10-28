# Ace Mail

**Your mail, on your device, on every platform.** A native IMAP/SMTP mail client
in Dart and Flutter — Android, iOS, macOS, Windows and Linux from one codebase.
No account with us, no server of ours, no analytics, nothing to sign up for. It
talks to your provider directly, which is what a mail client used to mean.

> No AI slop. Just code, design, and software worth using.

## Why Ace Mail

**Nothing of yours passes through anything of ours.** There is no backend. The
app opens IMAP and SMTP connections to your provider and nothing else, so there
is no server of ours to breach, no account of ours to close, and no analytics
key anywhere in the source. Credentials are sealed with AES-256-GCM in a single
file on the device, with the key in the platform keychain — not a token in
`SharedPreferences`, not a password in plain text, not a session on a server that
could be asked for them. The three things it *does* send beyond your mail are
named in Settings and two of them are off by default: the release check (once a
day, to GitHub, no identifiers), sender pictures (Gravatar/BIMI), and remote
images in a message.

**The assistant asks before it acts.** Chyme can read your mail and propose
changes to it — star, archive, delete, reply, block a sender — but every one of
those arrives as a card with **Do it** and **No**, and nothing touches the
mailbox until you press one. It never sends: a reply it writes opens in your
composer. It runs against **any OpenAI-compatible endpoint you point it at**,
with your own key, so the model is your choice rather than ours.

**One-time codes without opening the mail.** A code in a subject is picked out
as the row is built and shown as a chip one tap from the clipboard. For mail
whose subject mentions a code without containing one, the first few kilobytes of
the body are fetched and searched — bounded to a handful of rows per page. The
two seconds that saves, forty times a day, is the kind of thing a mail client is
for.

**It looks like it belongs on the device it is on.** Three design systems, each
doing the job it is good at: **Astryx** for the tokens, **Material 3 Expressive**
for how the controls behave, and **Apple's glass** for the surfaces on iOS — with
a **glass studio** so the blur, the tint and whether the glass is frosted or
smoked are yours to set. Fifteen accents, each walked along its own lightness
until a label on it clears AA against the tinted surface it actually sits on, and
a test that checks all fifteen in both modes.

**Fast where it is felt.** The SMTP connection is kept and warmed instead of
opened per message; the copy in Sent is filed behind the composer rather than in
front of it; signing in returns as soon as the login is accepted, with the first
page loading behind the list's skeleton; a thousand messages are cached so a
folder you have read opens without the network. Signing in, sending and opening
a folder are the three things you do a hundred times a day, and each one was
measured rather than assumed.

**It ships as packages, not zips.** An AppImage that runs on any distribution, a
Windows installer with a Start-menu entry and an uninstaller, a `.dmg`, an
unsigned `.ipa`, and both Android ABIs. Every one of them built by CI on the
platform it targets, from a tag, and attached to the release.

**And it is checked.** Over six hundred tests, analysis that fails the build on a
lint, and CI that builds all five platforms on every push. The claims in this
file that can be tested — contrast, the transport, the HTML sanitiser, the
credential store, the version comparison — have tests named after them, and the
ones that cannot be tested here say so.

## Downloads

Every release carries one file per platform, in the format that platform
installs:

| Platform | File | How it installs |
| --- | --- | --- |
| Android | `AceMail-<version>-arm64-v8a.apk` (and `armeabi-v7a`) | Sideload, or `adb install` |
| iOS | `AceMail-<version>-ios-unsigned.ipa` | Unsigned — re-sign with your own certificate, or use a sideloading tool |
| macOS | `AceMail-<version>-macos-unsigned.dmg` | Open the disk image, drag the app to Applications |
| Windows | `AceMail-<version>-windows-x64-setup.exe` | Run the installer: Start-menu entry, uninstaller, optional desktop shortcut |
| Linux | `AceMail-<version>-x86_64.AppImage` | `chmod +x` and run. Any distribution — it carries its own libraries. A `.tar.gz` of the same bundle is there too. |

The Apple builds are unsigned: signing needs a certificate and a provisioning
profile this repository does not hold. The AppImage is the Linux one to take —
a `.deb` would only install on the Debian family, and an AppImage runs on
Ubuntu, Fedora and Arch alike.

## Design

**A hybrid, deliberately.** No single design system covers what this app has to
be, and pretending otherwise is how a mail client ends up looking like a
settings pane.

Three sources, and what each one is for:

| Source | What comes from it |
| --- | --- |
| **Astryx** (Meta, [astryx.atmeta.com](https://astryx.atmeta.com)) | The tokens: type scale, spacing, radii, semantic colour roles. The vocabulary every widget speaks. |
| **Material 3 Expressive** (Google) | The behaviour of the controls: the switch's spring and its tick, the floating navigation bar's shape and its moving label, the shape-morph pull-to-refresh, the state layers. |
| **Liquid Glass** (Apple) | The see-through surfaces on iOS, approximated — a heavier backdrop blur over a thinner fill, since the real material is not reachable from Flutter without a plugin. |

The seams are deliberate and load-bearing. **Astryx is the vocabulary, Material
is the grammar, and Apple's material is the surface.** Colour and type come from
one place, so nothing is a near-miss of anything else; motion and control shape
come from the system whose users have those gestures in their thumbs; and the
material follows the platform, because a frosted panel is native on one and a
stall on another.

Where the three disagree, the *tokens* win, because they are the only ones the
app owns. Where the platform matters — a blur that costs a framebuffer readback
on Android 11, a spring that Android users expect — the platform wins, and
`lib/widgets/ace_glass.dart` is where that decision is written down rather than
scattered.

Concretely, `lib/theme/astryx_tokens.dart` carries the real token set:

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

## What it does

**Providers and signing in**

- Any IMAP/SMTP provider. Gmail, Yahoo, iCloud, Zoho, GMX and Yandex are
  recognised from the address; anything else takes manual hosts. Gmail signs in
  with **Google** — no password, nothing stored — and the rest use an **app
  password**. The built-in list is deliberately short: every entry works
  **free**, over IMAP/SMTP. Providers that need an OAuth this app does not
  implement (Outlook), a paid bridge (Proton), a paid plan (Fastmail, Rediffmail)
  or that dropped free IMAP for new accounts (Zoho) are not offered — a provider
  that cannot work is a dead end you only find after typing a password.
- A step-by-step guide behind the `?` on the sign-in screen and in the mailbox:
  app passwords, manual settings, and what each connection error means.
- Several accounts at once, switched from the header at the top of the rail. Each
  keeps its own credentials, its own last-seen message marker and its own
  session — removing one does not disturb the others.

**Reading**

- Browse every folder with its message count, capped at 999+, accent-tinted when
  something in it is unread. Container folders such as Gmail's `[Gmail]` are
  filtered out.
- Forty messages at a time, paged, with a thousand cached locally so a folder you
  have read opens instantly.
- The top bar is the **search bar**, with voice search beside it and Sort & filter
  and Chyme next to that. Pull down to refresh — the indicator is the shape morph,
  scrubbed by the drag — or Ctrl/Cmd+R.
- HTML rendered, with a plain-text toggle per message, and attachments listed and
  saveable.
- **Images are placeholders until you ask.** Sources are resolved, so a
  protocol-relative `//cdn.example/logo.png` loads too, and a 1×1 tracking pixel
  is dropped rather than becoming a placeholder in a message with no images in
  it. Off by default: fetching a remote image tells the sender's server you
  opened the mail.
- Sender pictures, best source first: the domain's **BIMI** logo, then Gravatar,
  then an initials chip. Off by default, because both lookups tell a third party
  which domains are in your mail.
- Sort by newest, oldest, sender, subject or unread first; filter to all, unread,
  flagged, or only the mail carrying a code.

**Acting on mail**

- Compose, reply, reply-all, **forward** — a forward quotes the original's headers
  and carries its attachments across. Replies set `In-Reply-To` and `References`,
  so they thread correctly everywhere else.
- Star, mark read or unread, **archive**, **file into any folder**, **mark as
  spam**, delete. Delete moves to Trash; when a provider has no Trash folder the
  app says so and asks before deleting permanently — it never quietly destroys
  mail.
- **Mark a whole folder read** and **select all** on the page, so a full inbox is
  two taps rather than forty.
- Swipe either way to act — archive, delete, read/unread or flag, each direction
  configured separately.
- **Send later.** A message can be scheduled; the same background worker that
  checks for mail sends it when its moment comes.
- **Address suggestions** while you type, from contacts the app already has:
  prefix matches first, nobody offered twice, never your own address back to you.
- **Contacts**, built from your mail as it loads and importable from the device's
  address book behind a button — permission asked for at that moment, nothing
  written back, nothing sent anywhere.

**Chyme, the assistant**

- Reads the mail in front of you and proposes what to do with it: search, read,
  star, mark read, archive, delete, reply, block a sender, keep a contact.
- **Every change waits for a button.** Each proposal is a card — *Chyme wants to ·
  Star "Re: invoice"* — with **Do it** and **No**.
- It never sends. A reply it writes opens in your composer for you to edit.
- Your endpoint, your model, your key. The model and the tone are two chips in its
  own header.
- Its first screen is a hero with the suggestions fanned along an arc, because a
  menu of seven prompts is a menu nobody reads.

**The look**

- Light and dark, following the system, with **true black** for OLED.
- **Fifteen accents.** The theme is global: every surface is the accent-tinted
  Milk or Ink, so changing the accent changes the page, not just the buttons.
- **Glass studio** — blur radius, tint strength, and a tint inversion for smoked
  instead of frosted, with a preview drawn by the same material code as every
  other surface.
- **Four launcher marks**, previewed at the size and on the accent they will wear,
  with a matching monochrome layer for Android's themed icons.
- Text size multiplies the device setting; list density comfortable or compact;
  gesture navigation throughout; a confirmation before the app closes.

**Under the hood**

- An update checker that asks GitHub once a day, shows what changed, and compares
  the build number as well as the name.
- New-mail notifications from a background worker, with quiet hours and private
  previews as switches — the preview one is on, so a notification says mail
  arrived rather than who sent it.
- Credentials sealed with AES-256-GCM on the device, the key in the platform
  keychain, and a `0600` key file beside the record for machines where the
  keychain will not answer.

## Getting it running

The Android project is included, so that target works out of the box:

```bash
git clone https://github.com/tab-gl/AceMail.git
cd AceMail
flutter pub get
flutter run                 # or: flutter build apk --release
```

### What CI verifies, and what it does not

CI runs `flutter analyze` and `flutter test` on every push and pull request.

| Target | In CI | Notes |
| --- | --- | --- |
| Android (release APKs) | **Every run** | split per ABI, signed, signer checked |
| Linux desktop | **Release tags and manual runs** | GTK and libsecret installed by the job |
| iOS (unsigned) | **Release tags and manual runs** | macOS runner; the runner is generated, then built |
| macOS, Windows | No | need their runner projects generated first (below) |

The Linux and iOS jobs are gated to releases because they are slower, and a
release is the point where a build that does not compile would matter. Run
them by hand from the Actions tab (`workflow_dispatch`) to check a change first.

### iOS

Needs a Mac with Xcode to run. The iOS runner is not committed: CI generates
it from Flutter's own template with `tool/ios/setup_ios.sh`, which also applies
what Ace Mail needs on top. To work in Xcode locally, run the same script once:

```bash
IOS_GOOGLE_CLIENT_ID=<your iOS OAuth client ID> tool/ios/setup_ios.sh
flutter build ios --no-codesign --debug
```

The script sets the permission strings (Face ID, microphone, speech), the
background mail check (its identifier must equal the Dart task name), the
Google client for sign-in, the bundle identifier (which matches Android's
`app.tab.mail`), the voice channel, and the Files-app folder for saved
attachments. Google sign-in on iOS needs `IOS_GOOGLE_CLIENT_ID` as a repository
secret; without it the rest of the app still builds.

Three iOS differences from Android, all on purpose:

* **Voice search asks for the microphone.** iOS runs speech recognition inside
  the app, so it needs the microphone and speech permissions that Android's
  design avoids. The first tap asks, and the answer is the person's to give.
* **Saving an attachment goes to the Files app.** iOS has no save dialog for an
  app to open, so the file lands in Ace Mail's folder under *On My iPhone*,
  never over an earlier save.
* **Background checks are the system's to schedule.** iOS decides when the
  mail check runs, so it can come later than fifteen minutes.

Signing and distribution need an Apple developer account and are not set up.

### Linux

The Linux project is committed. Linux has no `google_sign_in`, so Gmail on
Linux signs in through the browser instead. That needs a **Desktop** OAuth
client from the same Google Cloud project, passed at build time:

```bash
flutter run -d linux \
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID=... \
  --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...
```

Unlike Android and iOS, the desktop sign-in keeps a refresh token, so the person
is not sent back to the browser every hour. It is stored in the system keychain
(libsecret), beside the passwords for the other providers, and never in a plain
file. Without the two defines the app builds and says Gmail is not configured
on this build. CI reads the same two values from repository secrets.

Linux needs `libsecret` for the keychain:

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

   A SHA-1 fingerprint is **40 hex characters, in five groups of two**. The
   console will happily accept fewer, and then nothing matches: a fingerprint
   pasted from halfway along, or with the groups run together, produces the same
   `clientConfigurationError` as a wrong one. If the field shows four groups
   rather than five, it is not a SHA-1.

2. **A web OAuth client**, in the same project. Its ID is what Android's
   Credential Manager wants as `serverClientId`, and it is the one in
   `GoogleAuth.clientId`:

   ```
   919591212641-7m696qr165fh1ir4uo6d761jn7nnk4kg.apps.googleusercontent.com
   ```

   If that ID turns out to be an *Android* client rather than a web one, the
   value is rejected and the sign-in fails with `clientConfigurationError` — the
   client *type* is part of the identity. Making one:

   1. Open
      <https://console.cloud.google.com/apis/credentials> with the project
      selected at the top. **APIs & Services → Credentials** reaches the same
      page.
   2. **+ Create credentials → OAuth client ID.**
   3. **Application type: Web application.** This is the step that matters. An
      Android client is a different kind of thing and cannot be used here.
   4. **Name:** anything — "Ace Mail (server client)" says what it is for.
   5. **Authorised JavaScript origins:** leave **empty.** Nothing in this app
      runs in a browser, so there is no origin to name.
   6. **Authorised redirect URIs:** add exactly `http://localhost`

      Linux and Windows sign in through the system browser and catch the answer
      on a loopback port, and Google allows any port on `http://localhost` for
      that — so this one entry covers the app picking whatever port is free.
      Skip it and the desktop flow fails with `redirect_uri_mismatch`, which
      names a URL you never typed.
   7. **Create.** The dialog shows the **Client ID**; copy it, and copy the
      **client secret** from the same dialog.
   8. Put the ID in `GoogleAuth.clientId` in `lib/services/google_auth.dart`,
      and add both values as repository secrets:

      | Secret | Value |
      | --- | --- |
      | `GOOGLE_DESKTOP_CLIENT_ID` | the same client ID |
      | `GOOGLE_DESKTOP_CLIENT_SECRET` | the client secret |

      Android does not need the secret — Credential Manager only wants the ID as
      an audience — but the desktop flow does, and it is passed in at build time
      rather than compiled in.

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

Your password is stored sealed on this device — AES-256-GCM, key in the platform
keychain — and sent only to your own mail provider over TLS.

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
    account_store.dart      the sealed credential record (AES-256-GCM)
  models/                   account, folder, summary, full message
  services/mail_service.dart  IMAP + SMTP over enough_mail
  services/chyme.dart       the assistant's prompt, tools and parsing
  services/contacts.dart    the addresses the app has seen, and the saved ones
  services/device_contacts.dart  the device's address book, read on request
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
| Appearance | Accent | Fifteen accents, each checked for contrast |
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
- **Secure-storage failures are reported**, not swallowed. A record that will
  not open, or an account that could not be saved, says so — and a keychain that
  will not answer is not one of them any more: the key file beside the record is
  what keeps saved accounts open across a start.
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
- The launcher icon is an adaptive icon with four marks to choose from — Ink,
  Heart, Bear, Doodle — each with a monochrome layer for Android's themed icons,
  and each drawn at 60% of the canvas so it sits inside the safe zone rather than
  shrinking inside its tile. The in-app `BrandMark` draws from the same 108-unit
  geometry, so the two never drift apart. `AceLoader` is the Material 3
  Expressive shape morph, not a progress ring: one form travelling through
  Material's shape families, which is what "loading" looks like in that system.
- The launch window is painted in the app's own background colour with that
  mark, so the app appears to open straight onto its UI instead of flashing a
  blank screen first.
- The release manifest declares `android.permission.INTERNET`. Flutter's
  template only puts it in the debug and profile manifests, so a release build
  without it fails every connection with
  "Failed host lookup … errno = 7".
- The APK is built for `armeabi-v7a` and `arm64-v8a` only. `x86`/`x86_64` are
  emulator and ChromeOS images, and shipping them just inflates the download.
