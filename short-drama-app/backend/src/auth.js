'use strict';
const crypto = require('node:crypto');
const { run, get } = require('./db');
const SECRET = process.env.JWT_SECRET || 'dev-only-change-me-jwt-secret';
const b64 = (b) => Buffer.from(b).toString('base64url');
const unb64 = (s) => Buffer.from(s, 'base64url');
function sign(payload, ttlSec) {
  const h = b64(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const now = Math.floor(Date.now() / 1000);
  const p = b64(JSON.stringify({ ...payload, iat: now, exp: now + ttlSec }));
  const sig = crypto.createHmac('sha256', SECRET).update(`${h}.${p}`).digest('base64url');
  return `${h}.${p}.${sig}`;
}
function verify(token) {
  if (!token) return null;
  const parts = token.split('.'); if (parts.length !== 3) return null;
  const expect = crypto.createHmac('sha256', SECRET).update(`${parts[0]}.${parts[1]}`).digest();
  let sig; try { sig = unb64(parts[2]); } catch { return null; }
  if (sig.length !== expect.length || !crypto.timingSafeEqual(sig, expect)) return null;
  let payload; try { payload = JSON.parse(unb64(parts[1]).toString()); } catch { return null; }
  if (!payload.exp || payload.exp < Math.floor(Date.now() / 1000)) return null;
  return payload;
}
const uid = () => crypto.randomUUID();
const hash = (s) => crypto.createHash('sha256').update(s).digest('hex');
function issueTokens(userId) {
  const accessToken = sign({ sub: userId, type: 'access' }, 3600);
  const refreshToken = sign({ sub: userId, type: 'refresh', jti: uid() }, 30 * 24 * 3600);
  // Prune this user's expired refresh rows so the table cannot grow unboundedly.
  run('DELETE FROM refresh_tokens WHERE userId=? AND expiresAt<=?', userId, new Date().toISOString());
  run('INSERT INTO refresh_tokens(id,userId,tokenHash,expiresAt,createdAt) VALUES(?,?,?,?,?)',
    uid(), userId, hash(refreshToken), new Date(Date.now() + 30 * 24 * 3600e3).toISOString(), new Date().toISOString());
  return { accessToken, refreshToken };
}
function rotateRefresh(oldToken) {
  const p = verify(oldToken); if (!p || p.type !== 'refresh') return null;
  const h = hash(oldToken);
  const row = get('SELECT * FROM refresh_tokens WHERE tokenHash=?', h);
  if (!row) return null;
  if (row.revoked) {
    // Reuse of an already-rotated token: treat as theft — revoke the whole family.
    run('UPDATE refresh_tokens SET revoked=1 WHERE userId=?', row.userId);
    return null;
  }
  if (row.expiresAt <= new Date().toISOString()) return null; // DB-side expiry (not just the JWT exp)
  run('UPDATE refresh_tokens SET revoked=1 WHERE id=?', row.id);
  return issueTokens(row.userId);
}
/**
 * Firebase ID-token verification modes (see firebaseAuthMode):
 *  - 'firebase': REAL RS256 verification against Google's public JWKS
 *    (src/firebase.js) — active when FIREBASE_PROJECT_ID is set.
 *  - 'dev': accepts ANY non-empty token (claims decoded without a signature
 *    check) — only when AUTH_DEV_MODE=1 (or the legacy FIREBASE_AUTH_DEV=1)
 *    is set explicitly. Must never ship.
 *  - 'none' (default): /auth/firebase rejects with 501, like production.
 */
const firebase = require('./firebase');
function firebaseAuthMode() {
  if (process.env.FIREBASE_PROJECT_ID) return 'firebase';
  if (process.env.AUTH_DEV_MODE === '1' || process.env.FIREBASE_AUTH_DEV === '1') return 'dev';
  return 'none';
}
function devDecodeFirebaseToken(idToken) {
  const parts = String(idToken).split('.');
  if (parts.length === 3) {
    try {
      const c = JSON.parse(unb64(parts[1]).toString());
      if (c && (c.sub || c.user_id || c.uid)) {
        return { firebaseUid: c.sub || c.user_id || c.uid, email: c.email || null, name: c.name || null, picture: c.picture || null, isAnonymous: !c.email };
      }
    } catch { /* fall through */ }
  }
  return { firebaseUid: 'dev-' + hash(String(idToken)).slice(0, 32), email: null, name: null, picture: null, isAnonymous: true };
}
module.exports = { sign, verify, issueTokens, rotateRefresh, devDecodeFirebaseToken, firebaseAuthMode, verifyFirebaseIdToken: firebase.verifyFirebaseIdToken, uid, hash };
