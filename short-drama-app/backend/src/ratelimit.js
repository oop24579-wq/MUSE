'use strict';
/**
 * In-memory sliding-window rate limiting (zero dependencies).
 *
 * Two buckets, both keyed by client IP and configurable via env:
 *   - auth bucket: POST /api/v1/auth/* — strict, blunts credential brute
 *     force and mass guest-account creation (security audit RL1).
 *       RATE_LIMIT_AUTH_MAX (default 60) per RATE_LIMIT_AUTH_WINDOW_MS
 *       (default 1 hour). Tighten to ~30 in production once real traffic
 *       baselines are known.
 *   - API bucket: all other /api/v1/* traffic.
 *       RATE_LIMIT_API_MAX (default 600) per RATE_LIMIT_API_WINDOW_MS
 *       (default 10 minutes).
 * Blocked requests get 429 {error:{code:'RATE_LIMITED'}} + Retry-After.
 *
 * State is per-process memory: it resets on restart and does not coordinate
 * across replicas. For multi-instance production, put the same limits on
 * the reverse proxy / Firebase App Check as well (see README).
 */
const intEnv = (name, dflt) => { const v = parseInt(process.env[name] || '', 10); return Number.isFinite(v) && v > 0 ? v : dflt; };

function createLimiter({ windowMs, max }) {
  const hits = new Map(); // key -> sorted array of hit timestamps (ms)
  return {
    check(key, nowMs = Date.now()) {
      const cutoff = nowMs - windowMs;
      let arr = hits.get(key) || [];
      arr = arr.filter((t) => t > cutoff);
      if (arr.length >= max) {
        hits.set(key, arr);
        return { allowed: false, retryAfterSec: Math.max(1, Math.ceil((arr[0] + windowMs - nowMs) / 1000)) };
      }
      arr.push(nowMs);
      hits.set(key, arr);
      if (hits.size > 10000) { // opportunistic cleanup so the map cannot grow forever
        for (const [k, v] of hits) if (!v.length || v[v.length - 1] <= cutoff) hits.delete(k);
      }
      return { allowed: true };
    },
    reset() { hits.clear(); },
  };
}

const authLimiter = createLimiter({
  windowMs: intEnv('RATE_LIMIT_AUTH_WINDOW_MS', 3600e3),
  max: intEnv('RATE_LIMIT_AUTH_MAX', 60),
});
const apiLimiter = createLimiter({
  windowMs: intEnv('RATE_LIMIT_API_WINDOW_MS', 600e3),
  max: intEnv('RATE_LIMIT_API_MAX', 600),
});

/** Pick the bucket for a request (null = not rate limited). */
function limiterFor(req, pathname) {
  if (req.method === 'POST' && pathname.startsWith('/api/v1/auth/')) return authLimiter;
  if (pathname.startsWith('/api/v1/')) return apiLimiter;
  return null;
}

module.exports = { createLimiter, authLimiter, apiLimiter, limiterFor };
