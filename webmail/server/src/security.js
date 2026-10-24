import crypto from 'node:crypto';
import dns from 'node:dns/promises';
import ipaddr from 'ipaddr.js';

const key = () => {
  const raw = process.env.CREDENTIAL_ENCRYPTION_KEY;
  if (!raw) throw new Error('CREDENTIAL_ENCRYPTION_KEY is not configured');
  const bytes = Buffer.from(raw, 'base64');
  if (bytes.length !== 32) throw new Error('CREDENTIAL_ENCRYPTION_KEY must be a base64-encoded 32-byte key');
  return bytes;
};
export function encryptJson(value) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key(), iv);
  const body = Buffer.concat([cipher.update(JSON.stringify(value), 'utf8'), cipher.final()]);
  return Buffer.concat([Buffer.from([1]), iv, cipher.getAuthTag(), body]).toString('base64');
}
export function decryptJson(encoded) {
  const bytes = Buffer.from(encoded, 'base64');
  if (bytes.length < 30 || bytes[0] !== 1) throw new Error('Unsupported encrypted credential record');
  const decipher = crypto.createDecipheriv('aes-256-gcm', key(), bytes.subarray(1, 13));
  decipher.setAuthTag(bytes.subarray(13, 29));
  return JSON.parse(Buffer.concat([decipher.update(bytes.subarray(29)), decipher.final()]).toString('utf8'));
}

// Avoid using user-supplied mail hosts as a path to loopback, private, link-local,
// or cloud metadata services. DNS is resolved before each connection.
export async function assertPublicMailHost(host) {
  if (typeof host !== 'string' || host.length > 253 || !/^(?=.{1,253}$)[a-zA-Z0-9.-]+$/.test(host) || host.endsWith('.') || host.includes('..')) throw new Error('Invalid mail server hostname');
  const name = host.toLowerCase();
  if (name === 'localhost' || name.endsWith('.localhost') || name.endsWith('.local') || name.endsWith('.internal') || name.endsWith('.test')) throw new Error('Local mail server hosts are not permitted');
  const records = await dns.lookup(name, { all: true, verbatim: true });
  if (!records.length) throw new Error('Mail server hostname did not resolve');
  for (const record of records) {
    const address = ipaddr.parse(record.address);
    if (address.range() !== 'unicast') throw new Error('Mail server must resolve only to public IP addresses');
  }
}
