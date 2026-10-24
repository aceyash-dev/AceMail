# AceMail Web

A separate Flutter/Dart webmail client for the AceMail project. It supports Google identity sign-in, connecting IMAP/SMTP mailboxes, listing folders and recent messages, reading plain-text message bodies, and sending plain-text email.

## Architecture

- **Frontend:** Flutter Web, deployed from this directory to Vercel.
- **API:** Node.js/Express in `server/`, deployed separately. It verifies Google ID tokens server-side, scopes each mailbox to the verified Google subject, and encrypts provider credentials at rest with AES-256-GCM.
- **Mail:** IMAP over TLS on port 993 and SMTP over TLS on port 465. Provider app passwords are recommended.
- **Storage:** The API uses SQLite, so it must run on a host with persistent disk. Do not deploy the SQLite backend as a stateless Vercel Function.

## Required Vercel environment variables

Set these for **Production, Preview, and Development** in the Vercel project:

- `GOOGLE_WEB_CLIENT_ID`: the OAuth 2.0 **Web application** client ID. Add the production domain and Vercel preview origins to Authorized JavaScript origins in Google Cloud.
- `ACEMAIL_API_BASE_URL`: the public HTTPS origin of the separately deployed API, without a trailing slash.

The Flutter build reads these only through Dart compile-time environment values. Never put a Google client secret or mail password in the frontend environment. The Google client ID is public by design; the OAuth client secret is not.

## Local development

```sh
cd webmail
flutter pub get
flutter run -d chrome \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID \
  --dart-define=ACEMAIL_API_BASE_URL=https://YOUR-HTTPS-API
```

## Automatic deployments

The Vercel project is linked to `aceyash-dev/AceMail` with the root directory set to `webmail`. Production builds follow commits to `main`; pull requests create preview deployments. Keep edits and app additions in this directory (or the deployment workflow) so Vercel rebuilds the web app automatically.

## Limitations to resolve before public launch

- The backend needs a persistent-disk host and valid production secrets. The Render blueprint in `server/render.yaml` is a starting point; it does not create a live service by itself.
- Only plain-text messages are displayed. HTML email is deliberately not rendered until a robust sanitizer and remote-content policy are added.
- Attachments, folders with provider-specific edge cases, SMTP submission tests, rate-limit tuning, backup/restore, and an independent security review are still required before treating this as a public production mail service.
