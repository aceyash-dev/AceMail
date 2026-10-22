# Changelog

Notable changes, newest first. Versions follow `pubspec.yaml`; the build number
after the `+` is the Android version code.

## 0.4.9+26

### Added
- **The trash does something now.** In the Trash folder the actions change:
  messages are **restored to the inbox** or **deleted permanently**, and there
  is an **Empty trash** action where the trash is and nowhere else — an action
  that destroys everything should not be one tap away from a folder where it
  means nothing. Emptying asks first, because an expunged message is gone from
  the server rather than moved, and it is the one action in the app that cannot
  be undone.
- **Two more settings**: group the list by date, and unread counts on folders.
- **Undo on the snackbar.** A swipe that deletes now offers to take it back, and
  the undo returns the message to the folder it came from rather than to the
  inbox. The mistake is one flick away, so the way back is on the bar.

### Changed
- **Every transient message goes through one helper**, so they have the same
  shape and the same place on screen. A message is recognised before it is read.
- **The package is `app.tab.mail`.** A different application id means a separate
  app: this installs *alongside* the old one rather than over it, and the old one
  keeps its mail. Uninstall it when you are satisfied the new one works.

### Noted
- `restore` on the controller already meant "restore the accounts from
  storage", so the message one is `restoreMessage`. Two things with one name is
  how a method ends up doing the wrong one.

## 0.4.8+25

### Why it felt laggy
Two causes, both found by reading rather than guessing:

- **One folder load rebuilt the list a dozen times.** Code detection applied
  each code and notified after every one, so a page of twelve messages meant
  twelve full rebuilds of the whole list. It notifies once per pass now.
- **Every row decoded a full-size avatar.** A 200px Gravatar in a 40px row is
  four times the pixels for none of the detail, on every row, while scrolling.
  Images are decoded at the size they are drawn.

### Changed
- **Rows are cards.** A surface of their own, a corner, and air around them.
  Bare rows on a flat page run together and each one is harder to pick out than
  the last.
- **Swipes arm sooner.** The threshold was a quarter of the row's width; it is
  under a fifth now, and the reveal follows the finger more closely.
- **The switch is Material 3 Expressive's**: a tick when it is on, a cross when
  it is off. Position is a thing you read; a tick is a thing you recognise.
- **OLED moved in with the theme**, where the dark theme is chosen.
- **The empty state waits.** A folder still being fetched shows the skeleton
  rather than "this folder is empty" — saying a folder is empty before it has
  been read is the app telling a story it does not know the end of.

### Added
- **A new icon**, built from the envelope artwork: the adaptive foreground, the
  square and round tiles, the in-app mark and the notification icon are all the
  same drawing now. The notification icon is the art flattened to one colour,
  because Android tints it and anything with colour in it comes out as a blob.

### Removed
- **Linux.** The desktop runner and its CI job are gone with it.

## 0.4.7+24

### Removed
- **The launch screen with the mark on it.** It drew the app's icon centred on
  the page, which is a splash screen by another name — a second thing to look at
  before the app appears. The native window is a plain fill now, in the colour
  the app opens onto, so it and the first Flutter frame are the same surface.

### Changed
- **OLED moved to Appearance**, where the rest of the theming lives.
- **iOS-style switches.** Cupertino's switch, because it is the one people
  already know — the shape and the travel are the same everywhere they have seen
  it, and it reads as a setting rather than a control.
- **The defaults show the mail.** Sender pictures and remote images are on.
  These are the two I had kept off, and they are the two that leak: a remote
  image tells the sender's server the message was opened, and a Gravatar lookup
  tells a third party who is in your mail. Both still have switches, and the
  warnings that matter — links and empty subjects — stay on. The test that
  asserted the old defaults was named "privacy-first"; it is now named for what
  it actually checks, because a test that lies about its own intent is worse
  than no test.

### Added
- **Provider marks in the domain picker**, drawn here rather than taken from
  anyone: an envelope, a cloud, a shield. A real provider logo is a trademark,
  and shipping the artwork would mean shipping licensed assets; a shape that
  says what kind of provider it is reads at a glance and belongs to nobody.
- **Reduce motion**, in a new Accessibility section. Transitions stop moving
  rather than moving faster — someone who asked for less motion asked for less
  motion. The loading indicator is exempt, because a still one looks like a hung
  app.

### Performance
- The list no longer keeps scrolled-off rows alive, and no longer adds a second
  repaint boundary to rows that already have one.
- The image cache is 80 MB rather than the default, which is sized for a phone
  showing a handful of pictures. Re-decoding the same attachment on every pass
  is the kind of cost that shows up as jank.

## 0.4.6+23

### Fixed
- **The reader collapsed to a column at the right edge.** My table change put a
  horizontal scroll view inside a widget span, and a span is laid out with
  unbounded width — so it asked for infinite width and the whole message fell
  apart. No scroller now, and `IntrinsicColumnWidth(flex: 1)` so a table sizes
  to its content, shares out the leftover, and shrinks rather than overflowing.
  That regression was mine, from 0.4.5, and the screenshot caught it.
- **The sidebar button did nothing.** It called `Scaffold.of(context)` with the
  app bar's context, which sits *above* the Scaffold, so it found nothing. A
  `GlobalKey<ScaffoldState>` now, and the drawer opens.

### Added
- **True black for OLED panels.** The dark theme goes to #000000, with the
  raised surfaces at #070707 through #1A1A1A. A pixel that is off draws no
  power, and on an OLED panel the difference is visible at the edges.
- **Mild haptics.** A tick when a swipe crosses its line — once per gesture, not
  once per frame — and a heavier knock for the destructive ones. Off switch
  included, because a mail client is used dozens of times a day and anything
  louder becomes noise.
- **Provider tiles in the domain picker**, and **every address a provider hands
  out**. Proton gives you proton.me, protonmail.com and pm.me; picking one
  silently would sign you in as an address you do not use, and you would only
  find out when a reply went to the wrong place. GMX and Yandex joined the list
  — and a test now fails if a provider is offered without IMAP/SMTP settings
  behind it, which is how I caught that I had added two without them.

### Removed
- **The splash screen.** It was a second loading screen for something the
  mailbox already shows: the list has a skeleton while it loads and the app bar
  says which folder is coming. Two of them meant waiting twice.

## 0.4.5+22

### Fixed
- **Tables render as grids.** Cells used to be joined with a few spaces, which
  is why a status table arrived as "Status Job Annotations" on one line and the
  columns meant nothing. Mail is laid out in tables more than in anything else,
  so this was most of what "renders badly" was. A `<table>` becomes a real
  `Table` now, each cell rendered with the renderer's own rules — so a link in a
  cell is still a link, a script in a cell still contributes nothing, and a
  table with no rows falls back to text rather than vanishing.
- **The sidebar icon is the sidebar icon.** The drawer toggle was a hamburger,
  which says "a menu". It is Hugeicons' `SidebarLeft`, which says what it opens.
- **The mark is back to the milk envelope on orange** — the launcher icon, the
  splash and the in-app mark. Restored from the commit that had it rather than
  redrawn, so it is the same drawing and not an approximation of it.

### Changed
- **The list is grouped, like the settings screen.** Messages are headed Today,
  Yesterday, This week, This month, Earlier, with no date dropped. A list of
  forty identical rows tells you nothing about where to start; the same rows
  under headings tell you immediately. The order of the headings is fixed, so
  they do not shuffle as mail arrives, and an empty group is not shown.

### Improved
- Opening the app clears the notification for that account: you have seen it, so
  it is no longer news.

## 0.4.4+21

New-mail notifications, which had been outstanding for three passes.

### Added
- **Notifications for new mail**, checked in the background. `workmanager`
  schedules a periodic task at Android's floor of fifteen minutes, so the check
  runs when the app is closed rather than only while you are looking at your
  mail — which is what a foreground timer would have given, and what would have
  looked like it worked.
- The background task runs in its own isolate with no widget tree, so it reads
  everything from storage: the accounts and their passwords from the keychain,
  the highest uid seen per account from the settings. It connects, lists the
  inbox, and compares.
- **The first check says nothing.** With no record of what was seen, every
  message in the mailbox is technically new — reporting that would be a
  notification storm on the first run rather than a delivery. It records and
  stays quiet.
- **Deletions are not news.** Uids only climb, so a mailbox with fewer messages
  is not a delivery, and a message that arrived and was deleted between two
  checks is not announced — nobody wants to be told about mail they can no
  longer see. Seven tests cover these cases.
- The setting asks the platform for permission **at the moment it is turned on**,
  not at launch, and the switch shows what actually happened: a refused
  permission leaves it off rather than showing a state that did not occur.

### Notes
- `flutter_local_notifications` needs core library desugaring on Android. Without
  it the release build fails while dexing, with a message that never mentions
  notifications — so the Gradle change is in the diff next to the reason.
- The last-seen uid lives in the app's existing storage rather than a second
  one: it is one small number per account, and a background isolate can read it
  the same way the app does.

## 0.4.4+20

The icon bug, properly this time.

### Fixed
- **Icons rendered at the size of whatever box they sat in, not the size they
  were given.** A `Container` with a width and height hands its child *tight*
  constraints, so the `SizedBox.square(13)` inside a 44px button could not be
  13 — it was stretched to 44. Every icon inside a button, a chip, a list row or
  an app-bar slot was drawn at the full size of that box.
  This is why four passes at making the icons smaller changed nothing: the size
  was being overwritten every time, and the optical corrections I kept tuning
  were applied to a number that was then discarded. Measured, not guessed —
  `AceIconView size=18.48 rendered=Size(44.0, 44.0)`.
  The icon is centred in its box now, which gives it loose constraints and lets
  it be the size it asked for. With that fixed the scale could be set sensibly
  rather than compensatorily: optical correction 0.72 -> 0.85, a circular button
  draws at half its box, a button's own icon is 21/18.
- Four tests in `test/icon_size_test.dart` pin it, including the two shapes that
  were broken: an icon inside a button, and one in an app-bar slot. They measure
  rendered sizes, which is what the previous passes never did.

### Still outstanding
- **New-mail notifications.** Named again rather than quietly skipped. What it
  needs: `flutter_local_notifications`, an Android channel and permission, and a
  background service (WorkManager or a foreground service) to poll while the app
  is closed. A foreground timer would notify you only while you were already
  looking at your mail, which looks like it works and does not.

## 0.4.4+19

### Fixed
- **Icons, smaller again.** The optical correction went 0.78 -> 0.72, a circular
  button draws at 0.42 of its box, and a button's own icon is 19/16 rather than
  22/18. Third pass at this; the sizes are now in one place, so the next one is
  a single number.
- **The sidebar icon is ours.** The app bar's hamburger was Material's default
  `DrawerButton` — the last Material icon in the app, and the wrong weight
  beside everything else. It is a Hugeicon now. The last two raw `IconButton`s
  went the same way.
- **Fifteen accents, not sixteen.** Pink and rose were both in the list and look
  the same at a glance, which is a choice that does not mean anything. Rose is
  gone.

### Added
- **A warning before a link leaves the app.** A link's text is the sender's and
  need not be what the link does — `yahoo.com` can point anywhere. The address
  is shown first, with the scheme allowlist still in force underneath. On by
  default, with a switch.
- **A page cache.** Opening a folder you have already opened shows the last page
  immediately and refreshes behind you, instead of a blank list and a wait. A
  flag or read change updates the cache, so going back does not undo it.

### Not done, and why
- **JavaScript in messages.** Not a size problem — a decision. A mail body is
  attacker-controlled content, and running its script inside the app gives the
  sender code in the app's own context. Every serious client refuses it, and the
  renderer has refused it since the first audit. The need behind the request —
  a message that only renders with script — is better served by opening it in a
  browser, where the script runs under the browser's sandbox rather than ours.
- **New-mail notifications.** Still outstanding, and still needs a background
  service rather than a timer that dies with the app.

## 0.4.3+18

### Fixed
- **The sign-in sheet showed its fields twice.** The two-step change added the
  address row inside the new step but left the original above it, so Username
  and Domain appeared twice with the step indicator between them.
- **The navigation bar was black.** Nothing ever set the system bars, so Android
  drew its own default — a black band under a cream page. Both bars now follow
  the theme, in both modes.
- Icons are a touch smaller again: the optical correction went from 0.82 to
  0.78, and a circular button draws its icon at 0.46 of its box rather than
  0.50. Hugeicons still read fuller than Material glyphs at the same size.

### Added
- **Sixteen accents**, and **dynamic colour**. The system-colours switch takes
  the accent from the platform — Android's Monet, and the equivalent elsewhere —
  and feeds it through the same pipeline as a listed accent, so the contrast
  walk, the tinted surfaces and the readable inks all still apply. `dynamic_color`
  is pinned below 2.0: from 2.0 it depends on `material_ui`, a parallel Material
  implementation whose `ColorScheme` is a different type from Flutter's, which
  makes it unusable with a normal `MaterialApp`.
- **The mark follows the accent.** The flag in the app's own mark wears the
  theme colour now. The launcher icon cannot — Android draws it before the app
  exists — but everything inside the app can.
- Two settings: warn before sending with an empty subject (it asks once, then
  sends), and the system-colours switch above.

### HTML and CSS
- `display: none` and `visibility: hidden` are honoured. Mail hides its
  preheader this way, and ignoring it put a stray line of preview text at the
  top of every message.

### Still not done
- New-mail notifications. Named rather than left to be discovered.

## 0.4.2+17

### Fixed
- **Icons were oversized.** A Hugeicon fills its 24-unit grid much more
  completely than a Material glyph does, because a Material icon carries its own
  padding inside the box. At the same nominal size the new icons read about a
  fifth larger, which is why the reader's toolbar looked like it was shouting.
  Every icon now goes through `AceIconView`, which applies that correction in
  one place and also raises the stroke weight a little at small sizes, where a
  1.5-unit stroke goes spidery.
- The folder rail showed a dot beside each folder, which said nothing except
  that you had picked it. It shows the folder's own icon now — an inbox looks
  like an inbox, Sent like a paper plane, Trash like a bin.
- The "How to sign in" walkthrough is hidden once an account is connected: an
  app-password guide is clutter when mail is already flowing.

### Added
- **The app opens without an account.** "Look around first" on the sign-in
  screen goes straight to the mailbox, which is empty and says so. A sign-in
  screen that cannot be dismissed is a wall, and there is a whole app behind it.
- **Sign-in is two steps**, animated: your address, then your password and the
  servers. The address comes first because picking a provider is what fills the
  server fields in, so the second step usually has nothing to fill. A two-dot
  indicator shows where you are, and the panels slide in the direction you are
  travelling.

### Still not done
- New-mail notifications, and the CSS work beyond what 0.4.1 added. Both are
  named here rather than left to be discovered.

## 0.4.1+16

### Added
- **Hugeicons, throughout.** Every icon in the app is a Hugeicon now — 57
  distinct icons across 92 call sites. They go through `lib/theme/ace_icons.dart`,
  which names them by meaning (`AceIcons.search`, `AceIcons.trash`) and is the
  only file that names a Hugeicons icon, so the choice lives in one place.
  Hugeicons is a widget-based library rather than a font, so the icon parameters
  on the app's own widgets changed type with it.
- **CSS in the HTML renderer.** `<style>` blocks are read and applied, along
  with the `style` attribute: tag, class and id selectors, the last part of a
  descendant selector, later rules winning, and declarations beating the tag's
  own default the way a browser resolves them. Weight, italic, underline,
  colour (hex, `rgb()`, a few names), `font-size` as a multiplier capped at 2×,
  and `text-transform`. Still no JavaScript, and a `url()` in a rule never
  becomes a request.
- **Long-press to select.** Long-press picks a message out; the list goes into
  selection mode, a tap then picks rather than opens, and the app bar becomes a
  selection bar with mark-as-read, archive and delete. Bulk actions run one at a
  time and leave anything that failed selected, so a partial failure is visible
  rather than silent.

### Note on what the migration cost
Three bugs in my own tooling, all caught before shipping: the migration script
built its edits and never wrote them; the import rewriter dropped the
continuation line of a multi-line import; and the style blocks were being
ignored because `<style>` lives in the head and the renderer only walked the
body — which the CSS tests caught, not the analyzer.

### Still not done
- The sorting and folder pass, and the gesture-navigation pass.

## 0.4.0+15

The first 0.4. Patches follow from here until asked otherwise.

### Added
- **Raw headers**, behind a setting. The message's headers as the server sent
  them, at the foot of the reader in a box that scrolls on its own — for the
  Received chain, the authentication results, the unsubscribe address. Capped at
  16 KB: a header block can be longer than the body.
- **Choosing the account to send from.** With more than one account signed in,
  Compose shows a From row and the message is routed to the account you picked.
  A message sent from the wrong address is the kind of mistake you only notice
  when the reply comes back.
- **Your own picture**, in the account switcher and the rail, looked up even
  when third-party lookups are off — it is your address, and you are the one
  looking at it. Sender pictures keep the chain they had: BIMI, then Gravatar,
  then initials.
- The website, `ace-base.cc`, in About.

### Changed
- **The theme carries the accent's hue.** The surfaces were tinted 4.5%; they
  are tinted 11% (16% on the muted steps), so a brown theme gives a beige page
  rather than a grey one with brown buttons. That moved every contrast ratio, so
  the inks are now walked along their own lightness until they are readable on
  the surface they actually sit on — and the contrast test, which covers all ten
  accents in both modes, is what demanded it.
- **The tonal button belongs to the accent.** Material's expressive variant puts
  secondary a long way from the seed: with an orange accent, `secondaryContainer`
  came out *green*, which is why the Close button in About was green. Secondary
  and tertiary are the accent at two strengths now.
- **Back is a chevron, not an arrow.**
- **The loading lines are plain, current English.** They were in a period voice —
  "Prithee, a moment" — which is a joke that wears off in about a second, on a
  screen you see every launch.

### Not done
- Hugeicons: the package is a `HugeIcon` widget rather than `IconData`, so every
  icon call site changes shape and ~60 Material icons need matching by name.
- CSS in the HTML renderer: `<style>` blocks and class rules are still ignored.
- Long-press to select, sorting and folder work, and the gesture-navigation pass.

## 0.3.10+14

### Added
- **Geograph**, from the Typace foundry, as the app's typeface — replacing
  Questrial, which stays registered as the fallback because Geograph is a Latin
  face and a subject line can arrive in any script. Checked before wiring it in:
  87 KB, a real TrueType file (magic `00 01 00 00`, 18 tables), family name
  "Geograph Edit", full basic Latin plus €, •, — and ’, and the Latin-1
  accented range. Two glyphs the app used are not in it — `→`, which the tutorial
  used between steps, is now `›`, and `θ` appears only in a comment.

### Note
- The font could not be fetched from `typace.ace-base.cc`: this sandbox's egress
  proxy denies the host (`X-Squid-Error: ERR_ACCESS_DENIED`), so the earlier
  reading that the *server* refused was wrong. It was recovered from the
  `aceyash-dev/Typace` repository instead, which is the same asset.

## 0.3.9+13

### Fixed
- **Turning on "load images in messages" did nothing.** The setting never
  reached the renderer — the parameter was added to the wrong construction site
  — and the body was only re-rendered when the message changed, so switching it
  on did not load the images in the message already open. Both fixed.
- **BIMI profile pictures never appeared.** They were gated behind the Gravatar
  switch, which is off by default. BIMI is a DNS record the sender's own domain
  publishes and the logo is served from that same domain — a domain that already
  knows it emailed you — so it needs no opt-in. Gravatar still does.
- A protocol-relative image source (`//cdn.example/logo.png`, which most mail
  with a CDN uses) was treated as unfetchable and shown as a placeholder.
- A 1×1 tracking pixel produced an "Image" placeholder in the middle of messages
  that have no images in them at all.
- **The theme was not global.** Every surface role was pinned to a Milk or Ink
  constant, so changing the accent changed the buttons and left the page looking
  identical. Surfaces are now the accent-tinted tones — by hand, because
  Material's tonal palette desaturates them almost to grey. The accent is
  re-checked against the tinted page it actually sits on, since a dark accent on
  a dark page pulled towards it stops reading as a shape.
- `ic_launcher_round` was missing at every density, and the manifest never
  declared it. Built from the same art, with `android:roundIcon` set.

### Changed
- The ramp from `surfaceContainerLowest` to `surfaceContainerHighest` is
  asserted to stay distinct and to run light to dark, so tinting cannot flatten
  elevation.

## 0.3.8+12

### Fixed
- **Pulling didn't refresh.** The list used `AlwaysScrollableScrollPhysics`,
  which on Android resolves to *clamping* physics: a clamped list never
  overscrolls, so `CupertinoSliverRefreshControl` never reached its trigger
  distance and a pull did nothing. Bouncing physics now, on every platform, and
  a test drags past the trigger and asserts the folder reloads.
- **"Other" in the sign-in form silently kept the previous provider's servers.**
  Typing a username filled the servers from the default domain; switching to a
  custom domain left them in place, so the account would have signed in to the
  wrong server. Servers we filled are now cleared when the domain stops
  matching, and hand-entered ones are left alone.

### Added
- **Ten accents**, in Settings, with the whole app re-themed in place.
- **About is a sheet**, with the version, what the app does with your
  credentials, and where to find us: GitHub `@tab-gl`, Instagram `@tab.gl`.
- **The address is entered as username @ domain**, with a picker for the
  providers whose servers we know and a custom option for the rest.

### Changed
- The mark is redrawn to the reference: a curved postbox, a hooked flag in the
  accent, a letter in front with speed lines, a grey back and a ground line.
- The list fetches `HEADER.FIELDS (FROM SUBJECT DATE)` rather than the whole
  header block, and each row paints on its own layer.

## 0.3.7+11

### Fixed
- **The sidebar was gone.** Replacing the app bar spanned from `appBar:` to
  `floatingActionButton:` and swallowed the `drawer:` line between them, so on a
  phone there was no way to reach another folder at all. Restored, and the
  drawer is wider with the app's own surface colour.
- **Images broke the layout.** A picture rendered as a bracket of alt text
  dropped into the middle of a sentence. It is a placeholder now, in the shape's
  place, with the alt text inside it — and a remote image is only fetched when
  the reader asks, because loading one reports the open to the sender.
- A 300-character tracking URL ran off the side of the reader; long tokens get a
  zero-width space to wrap at.

### Changed
- **The loading indicator is a real Material shape morph.** Each family is a
  radial profile sampled at 128 angles and morphing interpolates all of them, so
  the shape passes through the intermediate forms. Each one is held briefly
  before travelling, which is what makes it read as a sequence of shapes.
- **The mark is an outline drawing** with the flag as the one filled, accented
  part — the accent, rather than the whole mark wearing it.
- The top bar no longer carries a refresh button. Pull down to refresh, or
  Ctrl/Cmd+R; the indicator is the shape morph scrubbed by the drag.

### Added
- A folder-change transition on the list, and a switch for loading images.

## 0.3.6+10

### Fixed
- **Refreshing blanked the list.** `openFolder` cleared the rows unconditionally,
  so a refresh emptied the screen and showed a skeleton. Reloading the folder
  already on screen keeps its contents until the new page arrives; only switching
  folders clears, because those rows belong to a different mailbox.
- The search field drew the theme's focus outline *inside* the pill, because
  only the resting border was unset.

### Added
- **One-time codes in the list**, without opening the mail: from the subject as
  each row is built, and from a bounded body preview for mail whose subject
  talks about a code but does not contain one. Tap to copy. Off-switch in
  settings.
- **Sort and filter chips**: newest, oldest, sender, subject, unread first; all,
  unread, flagged, codes.
- **About in the sidebar**, sharing one dialog with Settings.
- The top bar shows the current folder rather than the app icon, with refresh
  (which becomes the shape morph while it runs) beside search.

### Changed
- The launcher mark is a postbox with its flag up and a letter in front, in the
  accent orange on a Milk tile — the foreground and background swap places from
  the previous icon.
- The HTML renderer separates table cells and breaks rows, honours emphasis
  stated in a `style` attribute, and stops at a nesting depth rather than
  recursing through whatever a sender sent.
- The one-time-code rule takes the number *closest* to the words describing it,
  not the first one with any context nearby.

## 0.3.5+9

### Fixed
- **Search returned the wrong messages, or none.** `search()` ran a plain
  `SEARCH`, which answers with *sequence numbers* — positions in the mailbox —
  and then handed those to a UID fetch. It is a `UID SEARCH` now, so the results
  are the identifiers the rest of the app uses.
- **Deleting a message expunged the whole mailbox.** A bare `EXPUNGE` removes
  every message flagged `\Deleted`, including anything another client flagged
  and has not finished with. It now uses `UID EXPUNGE` when the server
  advertises UIDPLUS, and only falls back to the mailbox-wide form where the
  protocol offers nothing else.
- **Removing an account above the active one silently switched mailboxes.**
  The active index was clamped rather than decremented, so the account that was
  in front became a different account. Removing the account in front still moves
  to the next one, which is what it should do.
- **Email validation on the sign-in form was `contains('@')`.** It now uses the
  same validator as the compose screen.
- **The attachment size guard counted characters, not bytes**, and attached the
  oversized files anyway. It reads real file sizes and leaves off what does not
  fit, saying how many were left.
- Light-mode `onPrimary` on the brand orange was 2.87:1, failing AA on every
  filled button, badge and toggle. It is 5.7:1 now. Hint text and disabled ink
  were around 2.5:1; both are above 5:1.

### Added
- Reconnection: a dropped connection is retried once after an exponential
  backoff with jitter. Rejections and unknown delivery outcomes are never
  retried.
- A per-client request queue, so two operations cannot interleave a `SELECT`
  with a `FETCH` and read from the wrong folder.
- A typed error hierarchy — auth, connection, rejected, unknown outcome, server
  — replacing substring matching, with SMTP status codes used where the
  protocol provides them.
- Skeleton placeholders shaped like the message list and the reader.
- Six more shape-morph forms: rounded triangle, flower, square, star.
- Settings: messages per page, list density, ask before deleting, reconnect
  automatically, message view, and configurable swipe actions either way.
- Accessibility: buttons carry a button role, form fields carry their label.
- A Linux desktop build job in CI, and `dependabot.yml` for Dart packages and
  the workflow's own actions.

### Changed
- CI is read-only by default. Publishing is a separate job that asks for
  `contents: write` and never runs on a pull request; PRs are built with the
  debug key and never touch the release secrets.

## 0.3.4+8

### Added
- BIMI: sender logos are looked up via DNS-over-HTTPS at
  `default._bimi.<domain>`, falling back to Gravatar, then initials.
- Swipe actions on message rows, both directions configurable.
- Pull-to-refresh driven by the shape morph rather than a spinner.
- A splash with a rotating line while the first mailbox opens.

### Fixed
- Rounded rectangles used one superellipse stretched over the whole shape, so a
  wide, short card rendered as an oval. Corners are superelliptical now; the
  edges between them are straight.
- About reported a version typed into the source rather than the installed one.

## 0.3.3+7

### Fixed
- The Compose FAB sat on top of the reader's floating toolbar.
- A selected row inside a grouped card spilled past the card's corners.
- Whitespace-only content between blocks stretched a short message over
  several screens.

### Changed
- The loading indicator is the Material 3 Expressive shape morph, not a spinner.
- The launcher mark is a milk envelope on the brand orange, with the flap cut
  through it.

## 0.3.2+6

### Added
- Material 3 Expressive colour (Material's own `expressive` scheme variant,
  seeded from the brand orange), spring motion, squircle shape, and a shape
  morph on press.

## 0.3.1+5

### Added
- Settings with grouped sections, a grouped-list widget, and real preferences:
  theme, text size, mark-as-read, signature, ask before exiting.

### Changed
- The account switcher and help moved off the top bar; search took its place.

## 0.3.0+4

### Fixed
- Fourteen findings from a code audit, including delete safety, a link scheme
  allowlist, HTML parsing with a real parser, size limits, request generations,
  atomic connection, and a fail-closed release build.

## 0.2.0+3

### Added
- A release signing key, wired into CI with a signer check.
- Multi-account support, profile pictures, gesture navigation.

## 0.1.0+1

- First working client: IMAP/SMTP, folder rail, message list, reader, compose.
