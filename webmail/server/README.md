# AceMail Web API

Node.js API for the Flutter/Dart webmail client. It verifies Google ID tokens server-side, scopes mailbox records to the verified Google `sub`, encrypts mailbox credentials with AES-256-GCM, and connects to IMAP/SMTP with TLS certificate validation.

## Deploy

Deploy this directory as a Node service (Render blueprint included). Attach persistent storage at the configured database path. Configure `GOOGLE_WEB_CLIENT_ID`, `CREDENTIAL_ENCRYPTION_KEY` (32 random bytes, base64), and `WEB_ORIGIN` (exact deployed site origin). Keep the encryption key in the host's secret manager and back it up securely: losing it makes stored credentials unrecoverable. Never commit `.env` or database files.

## API

- `GET /health`
- `POST /api/auth/google` `{ idToken }`
- `GET /api/accounts` (Bearer Google ID token)
- `POST /api/accounts` `{ email,password,imapHost,imapPort:993,smtpHost,smtpPort:465 }`
- `GET /api/accounts/:accountId/folders`
- `GET /api/accounts/:accountId/messages?folder=INBOX&limit=30`
- `GET /api/accounts/:accountId/messages/:uid?folder=INBOX`
- `POST /api/accounts/:accountId/send` `{to,subject,text}`
- `DELETE /api/accounts/:accountId`

The API deliberately supports implicit TLS only: IMAP 993 and SMTP 465. STARTTLS is not implemented yet. Use provider app passwords where required. Message HTML is returned as data and must be sanitized before any browser rendering; do not insert it directly into `innerHTML` or an unsandboxed WebView.

## Production checklist

- Use HTTPS only and set the exact frontend origin in `WEB_ORIGIN`.
- Configure Google OAuth Web client authorized JavaScript origins and use the same client ID for the API audience.
- Set a strong unique encryption key, restrict host access, enable backups, and monitor storage usage.
- Add security review, abuse controls, message-size limits, pagination tests, and a sanitized HTML/attachment workflow before broad public launch.
- This is a starter API, not a substitute for a professional security review. IMAP/SMTP credentials grant mailbox access and must be handled accordingly.
