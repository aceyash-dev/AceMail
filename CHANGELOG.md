# Changelog

Notable changes, newest first. Versions follow `pubspec.yaml`; the build number
after the `+` is the Android version code.

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
