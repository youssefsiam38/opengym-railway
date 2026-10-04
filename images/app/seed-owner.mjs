// First-boot owner for the openGym Railway template.
//
// A fresh openGym has open sign-up and no admin; on a public Railway URL that means whoever finds
// it first owns it. The template runs invite-only, so somebody has to be inside already to hand out
// invites. This creates that somebody once, before the API starts: a profile named OWNER_NAME that
// signs in with OWNER_PASSWORD (openGym's own password sign-in, hashed with openGym's own
// hashPassword) and carries openGym's own `admin: true` flag.
//
// It only ever writes when db.json holds no profiles. Changing OWNER_PASSWORD later does nothing;
// the password is then the owner's to change in Settings. The password is never printed.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { hashPassword, passwordProblem } from './password.js';

const DATA = process.env.DATA_DIR || '/data';
const dbFile = path.join(DATA, 'db.json');
const name = String(process.env.OWNER_NAME || '').trim().slice(0, 40);
const password = process.env.OWNER_PASSWORD || '';
const log = msg => console.log(`[opengym-railway] ${msg}`);

let db = null;
if (fs.existsSync(dbFile)) {
  try { db = JSON.parse(fs.readFileSync(dbFile, 'utf8')); } catch (e) {
    // Never overwrite a db.json we cannot read: it may be the only copy of everyone's passkeys.
    console.error(`[opengym-railway] ERROR: ${dbFile} exists but is not valid JSON (${e.message}); refusing to touch it.`);
    process.exit(1);
  }
}
if (db && Array.isArray(db.users) && db.users.length > 0) {
  log(`owner seed skipped: ${db.users.length} profile(s) already exist`);
  process.exit(0);
}

if (!name) { console.error('[opengym-railway] ERROR: OWNER_NAME is empty.'); process.exit(1); }
const problem = passwordProblem(password, name);
if (problem) {
  console.error(`[opengym-railway] ERROR: OWNER_PASSWORD is not accepted by openGym's password policy (${problem}); use at least 10 characters that are not a common password.`);
  process.exit(1);
}

const created = new Date().toISOString();
const owner = {
  id: crypto.randomBytes(12).toString('base64url'),
  name,
  created,
  pw: { h: await hashPassword(password), set: created },
  admin: true
};
db = { users: [], creds: [], subs: [], invites: [], ...(db || {}) };
db.users = [owner];
fs.mkdirSync(DATA, { recursive: true });
const tmp = dbFile + '.tmp';
fs.writeFileSync(tmp, JSON.stringify(db, null, 2), { mode: 0o600 });
fs.renameSync(tmp, dbFile);
log(`owner profile "${name}" created (admin, password sign-in)`);
