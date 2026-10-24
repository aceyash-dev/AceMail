# AceMail Web

A separate Flutter/Dart web client for AceMail. The native app's direct IMAP/SMTP socket transport cannot run inside a browser; a secure HTTPS backend is required for real mailbox access.

## Build locally

```sh
cd webmail
flutter pub get
flutter run -d chrome \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_OAUTH_CLIENT_ID \
  --dart-define=ACEMAIL_API_BASE_URL=https://YOUR-HTTPS-API
```

## Required configuration

- `GOOGLE_WEB_CLIENT_ID`: OAuth **Web application** client ID with this site's origin authorized.
- `ACEMAIL_API_BASE_URL`: HTTPS URL for the separately deployed AceMail API.

Google sign-in is identity only. The API must validate ID tokens server-side and must never trust client-provided email claims. Mailbox credentials must only be transmitted over HTTPS, encrypted at rest with a managed secret, and never written to logs. Do not deploy with a placeholder API URL or claim mail access is ready until the backend endpoints are implemented, deployed, and tested.

## Deployment

The repository workflow builds this subproject with Flutter Web and publishes it to GitHub Pages. Set repository variable `GOOGLE_WEB_CLIENT_ID` and secret `ACEMAIL_API_BASE_URL` in GitHub Actions. Enable Pages with **GitHub Actions** as the source. The backend is a separate deployment and is not provisioned by GitHub Pages.
