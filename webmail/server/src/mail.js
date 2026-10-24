import { ImapFlow } from 'imapflow';
import nodemailer from 'nodemailer';
import { simpleParser } from 'mailparser';
import { assertPublicMailHost, decryptJson } from './security.js';

function imapOptions(c) { return { host: c.imapHost, port: c.imapPort, secure: c.imapSecure !== false, auth: { user: c.email, pass: c.password }, logger: false, greetingTimeout: 15000, socketTimeout: 30000 }; }
export async function withImap(encrypted, fn) {
  const c = decryptJson(encrypted);
  await assertPublicMailHost(c.imapHost);
  const client = new ImapFlow(imapOptions(c));
  try { await client.connect(); return await fn(client, c); } finally { try { await client.logout(); } catch { client.close(); } }
}
export async function listFolders(encrypted) {
  return withImap(encrypted, async client => (await client.list()).map(f => ({ path: f.path, name: f.name, specialUse: f.specialUse ?? null })));
}
export async function listMessages(encrypted, folder, limit = 30) {
  return withImap(encrypted, async client => {
    const lock = await client.getMailboxLock(folder);
    try {
      const mailbox = client.mailbox;
      const end = mailbox.exists ?? 0;
      if (!end) return [];
      const start = Math.max(1, end - Math.min(Math.max(Number(limit) || 30, 1), 50) + 1);
      const out = [];
      for await (const m of client.fetch(`${start}:${end}`, { uid: true, envelope: true, flags: true, internalDate: true, bodyStructure: false })) {
        const e = m.envelope;
        out.push({ uid: m.uid, subject: e?.subject ?? '(no subject)', from: e?.from?.map(a => ({ name: a.name ?? '', address: a.address ?? '' })) ?? [], to: e?.to?.map(a => ({ name: a.name ?? '', address: a.address ?? '' })) ?? [], date: (m.internalDate ?? e?.date ?? new Date()).toISOString(), seen: m.flags?.has('\\Seen') ?? false, messageId: e?.messageId ?? null });
      }
      return out.reverse();
    } finally { lock.release(); }
  });
}
export async function readMessage(encrypted, folder, uid) {
  return withImap(encrypted, async client => {
    const lock = await client.getMailboxLock(folder);
    try {
      const message = await client.fetchOne(Number(uid), { uid: true, source: true, envelope: true }, { uid: true });
      if (!message?.source) throw new Error('Message not found');
      const parsed = await simpleParser(message.source, { skipHtmlToText: true, skipTextToHtml: true });
      return { uid: message.uid, subject: parsed.subject ?? '(no subject)', from: parsed.from?.text ?? '', to: parsed.to?.text ?? '', date: parsed.date?.toISOString() ?? null, text: parsed.text ?? '', html: parsed.html ? String(parsed.html) : null };
    } finally { lock.release(); }
  });
}
export async function sendMessage(encrypted, input) {
  const c = decryptJson(encrypted);
  await assertPublicMailHost(c.smtpHost);
  const transporter = nodemailer.createTransport({ host: c.smtpHost, port: c.smtpPort, secure: c.smtpSecure !== false, auth: { user: c.email, pass: c.password }, tls: { rejectUnauthorized: true }, connectionTimeout: 15000, greetingTimeout: 15000, socketTimeout: 30000 });
  try {
    const to = String(input.to ?? '').split(',').map(x => x.trim()).filter(Boolean);
    if (!to.length || to.length > 20 || to.some(x => !/^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(x))) throw new Error('Enter valid recipient email addresses');
    const subject = String(input.subject ?? '').slice(0, 998);
    const text = String(input.text ?? '');
    if (text.length > 500000 || subject.length > 998) throw new Error('Message exceeds size limits');
    return await transporter.sendMail({ from: c.email, to, subject, text });
  } finally { transporter.close(); }
}
