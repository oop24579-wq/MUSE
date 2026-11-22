'use strict';
/**
 * Real Firebase ID-token verification (RS256) with zero dependencies.
 *
 * Firebase ID tokens are JWTs signed by Google with RS256. The public keys
 * are published as a JWKS at Google's securetoken endpoint; we fetch and
 * cache them (honoring Cache-Control max-age, capped at 24h), then verify:
 *   - signature (crypto.verify RSA-SHA256 against the JWK named by `kid`)
 *   - alg === 'RS256'
 *   - iss === https://securetoken.firebaseio.com/<projectId>
 *   - aud === <projectId>
 *   - exp in the future, iat not in the future (5 min leeway), sub present
 *
 * Config (env):
 *   FIREBASE_PROJECT_ID  — enables real verification (see auth.firebaseAuthMode)
 *   FIREBASE_JWKS_URL    — override the JWKS endpoint (tests point this at a
 *                          local stub serving a self-generated keypair)
 *
 * Tests can also inject the fetcher directly via __setFetchForTests().
 */
const http = require('node:http');
const https = require('node:https');
const crypto = require('node:crypto');

const DEFAULT_JWKS_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

let cache = { url: null, keys: new Map(), fetchedAt: 0, maxAgeMs: 3600e3 };
let fetchOverride = null;

function fetchJson(url) {
  if (fetchOverride) return fetchOverride(url);
  return new Promise((resolve, reject) => {
    const lib = url.startsWith('https:') ? https : http;
    lib.get(url, (res) => {
      if (res.statusCode !== 200) { res.resume(); return reject(new Error(`JWKS fetch failed: HTTP ${res.statusCode}`)); }
      const cc = /max-age=(\d+)/.exec(res.headers['cache-control'] || '');
      if (cc) cache.maxAgeMs = Math.min(parseInt(cc[1], 10) * 1000, 24 * 3600e3);
      let data = '';
      res.on('data', (c) => { data += c; });
      res.on('end', () => { try { resolve(JSON.parse(data)); } catch (e) { reject(e); } });
    }).on('error', reject);
  });
}

async function getPublicKey(kid, jwksUrl) {
  const stale = cache.url !== jwksUrl || Date.now() - cache.fetchedAt > cache.maxAgeMs;
  if (stale || !cache.keys.has(kid)) {
    const jwks = await fetchJson(jwksUrl);
    const map = new Map();
    for (const k of (jwks && jwks.keys) || []) if (k && k.kid) map.set(k.kid, k);
    cache = { url: jwksUrl, keys: map, fetchedAt: Date.now(), maxAgeMs: cache.maxAgeMs };
  }
  const jwk = cache.keys.get(kid);
  if (!jwk) return null;
  return crypto.createPublicKey({ key: jwk, format: 'jwk' });
}

/**
 * Verify a Firebase ID token. Returns the app-shaped claims object
 * ({firebaseUid, email, name, picture, isAnonymous}) or null when the token
 * is invalid for ANY reason. Throws only on JWKS fetch/transport errors
 * (callers should treat those as 401 too — an unverifiable token is not a
 * valid token — but the distinction is logged server-side).
 */
async function verifyFirebaseIdToken(idToken, opts = {}) {
  const projectId = opts.projectId || process.env.FIREBASE_PROJECT_ID;
  if (!projectId || !idToken) return null;
  const jwksUrl = opts.jwksUrl || process.env.FIREBASE_JWKS_URL || DEFAULT_JWKS_URL;
  const parts = String(idToken).split('.');
  if (parts.length !== 3) return null;
  let header, claims;
  try {
    header = JSON.parse(Buffer.from(parts[0], 'base64url').toString());
    claims = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
  } catch { return null; }
  if (!header || header.alg !== 'RS256' || !header.kid || !claims) return null;
  const key = await getPublicKey(header.kid, jwksUrl);
  if (!key) return null;
  let sigOk = false;
  try {
    sigOk = crypto.verify('RSA-SHA256', Buffer.from(`${parts[0]}.${parts[1]}`), key, Buffer.from(parts[2], 'base64url'));
  } catch { return null; }
  if (!sigOk) return null;
  const nowSec = Math.floor((opts.nowMs ?? Date.now()) / 1000);
  if (claims.iss !== `https://securetoken.firebaseio.com/${projectId}`) return null;
  if (claims.aud !== projectId) return null;
  if (!claims.exp || claims.exp <= nowSec) return null;
  if (claims.iat && claims.iat > nowSec + 300) return null;
  if (!claims.sub || typeof claims.sub !== 'string' || claims.sub.length > 128) return null;
  const provider = claims.firebase && claims.firebase.sign_in_provider;
  return {
    firebaseUid: claims.sub,
    email: claims.email || null,
    name: claims.name || null,
    picture: claims.picture || null,
    isAnonymous: provider === 'anonymous' || !claims.email,
  };
}

module.exports = {
  verifyFirebaseIdToken,
  DEFAULT_JWKS_URL,
  __setFetchForTests(fn) { fetchOverride = fn; },
  __resetCache() { cache = { url: null, keys: new Map(), fetchedAt: 0, maxAgeMs: 3600e3 }; },
};
