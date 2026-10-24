import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import Database from 'better-sqlite3';
import { OAuth2Client } from 'google-auth-library';
import { encryptJson, decryptJson, assertPublicMailHost } from './security.js';
import { listFolders, listMessages, readMessage, sendMessage } from './mail.js';

const required = ['GOOGLE_WEB_CLIENT_ID', 'CREDENTIAL_ENCRYPTION_KEY', 'WEB_ORIGIN'];
for (const name of required) if (!process.env[name]) { console.error(`Missing required environment variable: ${name}`); process.exit(1); }
const port = Number(process.env.PORT || 8080);
const origin = process.env.WEB_ORIGIN.replace(/\/$/, '');
const google = new OAuth2Client(process.env.GOOGLE_WEB_CLIENT_ID);
const db = new Database(process.env.DATABASE_PATH || './data/ace-mail-web.sqlite');
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');
db.exec(`CREATE TABLE IF NOT EXISTS accounts (id TEXT PRIMARY KEY, user_sub TEXT NOT NULL, email TEXT NOT NULL, encrypted_config TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(user_sub,email)); CREATE INDEX IF NOT EXISTS accounts_user_idx ON accounts(user_sub);`);
const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 1);
app.use(helmet({ crossOriginEmbedderPolicy: false, contentSecurityPolicy: false }));
app.use(cors({ origin, methods: ['GET','POST','DELETE','OPTIONS'], allowedHeaders: ['Content-Type','Authorization'], maxAge: 600 }));
app.use(express.json({ limit: '64kb', strict: true }));
app.use(rateLimit({ windowMs: 60_000, limit: 90, standardHeaders: 'draft-7', legacyHeaders: false }));
app.get('/health', (_req, res) => res.json({ ok: true, service: 'ace-mail-web-api' }));

async function auth(req, res, next) {
  try {
    const match = /^Bearer (.+)$/.exec(req.get('authorization') ?? '');
    if (!match) return res.status(401).json({ error: 'Sign in required' });
    const ticket = await google.verifyIdToken({ idToken: match[1], audience: process.env.GOOGLE_WEB_CLIENT_ID });
    const p = ticket.getPayload();
    if (!p?.sub || !p.email || p.email_verified !== true) return res.status(401).json({ error: 'Verified Google account required' });
    req.user = { sub: p.sub, email: p.email };
    next();
  } catch { res.status(401).json({ error: 'Google identity token is invalid or expired' }); }
}
app.post('/api/auth/google', async (req, res) => {
  try {
    if (typeof req.body?.idToken !== 'string' || req.body.idToken.length > 10000) return res.status(400).json({ error: 'Invalid identity token' });
    const ticket = await google.verifyIdToken({ idToken: req.body.idToken, audience: process.env.GOOGLE_WEB_CLIENT_ID });
    const p = ticket.getPayload();
    if (!p?.sub || !p.email || p.email_verified !== true) return res.status(401).json({ error: 'Verified Google account required' });
    res.json({ ok: true, user: { email: p.email, name: p.name ?? '', picture: p.picture ?? null } });
  } catch { res.status(401).json({ error: 'Google identity token verification failed' }); }
});
app.get('/api/accounts', auth, (req, res) => {
  res.json(db.prepare('SELECT id,email,created_at FROM accounts WHERE user_sub=? ORDER BY created_at').all(req.user.sub));
});
app.post('/api/accounts', auth, async (req, res) => {
  const b = req.body ?? {};
  const email = String(b.email ?? '').trim().toLowerCase();
  const imapHost = String(b.imapHost ?? '').trim();
  const smtpHost = String(b.smtpHost ?? '').trim();
  const password = String(b.password ?? '');
  const imapPort = Number(b.imapPort ?? 993), smtpPort = Number(b.smtpPort ?? 465);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || password.length < 1 || password.length > 1024 || ![993,143].includes(imapPort) || ![465,587].includes(smtpPort)) return res.status(400).json({ error: 'Invalid account details or unsupported ports' });
  try {
    await Promise.all([assertPublicMailHost(imapHost), assertPublicMailHost(smtpHost)]);
    // Only TLS-capable ports are supported. Port 143/587 are not accepted until explicit STARTTLS is implemented.
    if (imapPort !== 993 || smtpPort !== 465) return res.status(400).json({ error: 'This API currently supports implicit TLS only (IMAP 993 and SMTP 465).' });
    const id = cryptoId();
    const config = { email, password, imapHost, imapPort, imapSecure: true, smtpHost, smtpPort, smtpSecure: true };
    const encrypted = encryptJson(config);
    // Test IMAP credentials before saving them. No credentials are returned to the client.
    const { ImapFlow } = await import('imapflow');
    const client = new ImapFlow({ host: imapHost, port: imapPort, secure: true, auth: { user: email, pass: password }, logger: false, greetingTimeout: 12000, socketTimeout: 15000 });
    try { await client.connect(); await client.logout(); } catch { client.close(); return res.status(400).json({ error: 'Could not authenticate with IMAP. Check the host, address, and provider app password.' }); }
    db.prepare('INSERT INTO accounts(id,user_sub,email,encrypted_config) VALUES(?,?,?,?) ON CONFLICT(user_sub,email) DO UPDATE SET encrypted_config=excluded.encrypted_config').run(id, req.user.sub, email, encrypted);
    res.status(201).json({ id, email });
  } catch (e) { res.status(400).json({ error: safeMessage(e) }); }
});
function cryptoId() { return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 14)}`; }
function safeMessage(e) { const m = String(e?.message ?? 'Request failed'); return /hostname|public IP|resolve|credential|key/i.test(m) ? m : 'Could not complete the mail operation. Verify the settings and try again.'; }
function accountFor(req, res) {
  const id = String(req.params.accountId ?? '');
  const row = db.prepare('SELECT id,email,encrypted_config FROM accounts WHERE id=? AND user_sub=?').get(id, req.user.sub);
  if (!row) { res.status(404).json({ error: 'Mailbox not found' }); return null; }
  return row;
}
app.delete('/api/accounts/:accountId', auth, (req, res) => { const r = db.prepare('DELETE FROM accounts WHERE id=? AND user_sub=?').run(req.params.accountId, req.user.sub); res.status(r.changes ? 204 : 404).end(); });
app.get('/api/accounts/:accountId/folders', auth, async (req, res) => { const a = accountFor(req,res); if (!a) return; try { res.json(await listFolders(a.encrypted_config)); } catch { res.status(502).json({ error: 'Could not connect to this mailbox.' }); } });
app.get('/api/accounts/:accountId/messages', auth, async (req, res) => { const a = accountFor(req,res); if (!a) return; const folder = String(req.query.folder ?? 'INBOX'); if (folder.length > 255) return res.status(400).json({ error: 'Invalid folder' }); try { res.json(await listMessages(a.encrypted_config, folder, req.query.limit)); } catch { res.status(502).json({ error: 'Could not fetch messages from this mailbox.' }); } });
app.get('/api/accounts/:accountId/messages/:uid', auth, async (req, res) => { const a = accountFor(req,res); if (!a) return; const uid = Number(req.params.uid); const folder = String(req.query.folder ?? 'INBOX'); if (!Number.isSafeInteger(uid) || uid < 1 || folder.length > 255) return res.status(400).json({ error: 'Invalid message reference' }); try { res.json(await readMessage(a.encrypted_config, folder, uid)); } catch { res.status(404).json({ error: 'Message could not be loaded.' }); } });
app.post('/api/accounts/:accountId/send', auth, async (req, res) => { const a = accountFor(req,res); if (!a) return; try { const info = await sendMessage(a.encrypted_config, req.body ?? {}); res.json({ ok: true, messageId: info.messageId ?? null }); } catch (e) { res.status(400).json({ error: safeMessage(e) }); } });
app.use((err, _req, res, _next) => { console.error('Request rejected:', err?.type ?? 'internal_error'); res.status(err?.type === 'entity.parse.failed' ? 400 : 500).json({ error: err?.type === 'entity.parse.failed' ? 'Invalid JSON request' : 'Unexpected server error' }); });
app.listen(port, '0.0.0.0', () => console.log(`AceMail API listening on ${port}`));
