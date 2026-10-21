# Changelog

Notable changes, newest first. Versions follow `pubspec.yaml`; the build number
after the `+` is the Android version code.

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
