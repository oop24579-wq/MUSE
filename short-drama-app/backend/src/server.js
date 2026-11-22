'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { seed } = require('./seed');
const { handle, adminHandle, err } = require('./routes');
const captions = require('./captions');
// Fail fast in production on the well-known dev secrets; warn loudly otherwise.
for (const [name, dflt] of [['JWT_SECRET', 'dev-only-change-me-jwt-secret'], ['ADMIN_TOKEN', 'dev-admin-token-change-me']]) {
  if (!process.env[name] || process.env[name] === dflt) {
    if (process.env.NODE_ENV === 'production') { console.error(`FATAL: ${name} is unset or the dev default — refusing to start in production.`); process.exit(1); }
    console.warn(`WARNING: ${name} is unset or the dev default — fine for local dev, NEVER for production.`);
  }
}
seed();
captions.recoverOnStartup();
const ADMIN_DIR = path.join(__dirname, '..', 'public', 'admin');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.svg': 'image/svg+xml' };
function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = ''; let settled = false;
    const fail = (status, code, message) => { if (!settled) { settled = true; reject(Object.assign(new Error(message), { httpStatus: status, code })); } };
    // Once over the cap, stop accumulating (memory stays bounded at ~5MB)
    // but do NOT destroy the socket: the 413 must actually reach the client,
    // and destroying it first turned the response into a connection reset.
    req.on('data', (c) => { if (settled) return; data += c; if (data.length > 5e6) fail(413, 'PAYLOAD_TOO_LARGE', 'Request body too large'); });
    req.on('end', () => {
      if (settled) return; settled = true;
      if (!data) return resolve({});
      try {
        const parsed = JSON.parse(data);
        // A JSON `null`/number/string body is not an object: handlers access
        // body.xxx and would throw a 500 (security audit IN1). Normalize to {}.
        resolve(parsed && typeof parsed === 'object' ? parsed : {});
      } catch { reject(Object.assign(new Error('Request body is not valid JSON'), { httpStatus: 400, code: 'BAD_JSON' })); }
    });
    req.on('error', () => { if (!settled) { settled = true; resolve({}); } });
  });
}
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  try {
    if (req.method === 'OPTIONS') { res.writeHead(204, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': '*' }); return res.end(); }
    if (url.pathname === '/' || url.pathname === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ ok: true, service: 'hero-drama-backend', version: '1.0.0' }));
    }
    if (url.pathname === '/admin' || url.pathname.startsWith('/admin/')) {
      const rel = url.pathname === '/admin' ? 'index.html' : decodeURIComponent(url.pathname.slice('/admin/'.length));
      const file = path.join(ADMIN_DIR, rel);
      if (!file.startsWith(ADMIN_DIR + path.sep) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
        res.writeHead(404, { 'Content-Type': 'text/plain' }); return res.end('Not found');
      }
      res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
      return fs.createReadStream(file).pipe(res);
    }
    if (url.pathname.startsWith('/api/v1/admin/')) { const body = await readBody(req); return adminHandle(req, res, url, body); }
    if (url.pathname.startsWith('/api/v1/')) { const body = await readBody(req); return await handle(req, res, url, body); }
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: { code: 'NOT_FOUND', message: 'Not found' } }));
  } catch (e) {
    console.error(e);
    if (!res.headersSent) {
      if (e && e.httpStatus) err(res, e.httpStatus, e.code || 'ERROR', e.message);
      // Malformed percent-encoding (e.g. /series/%E0%A4%A) throws URIError
      // from decodeURIComponent — a client error, not a 500 (audit IN5).
      else if (e instanceof URIError) err(res, 400, 'BAD_PATH', 'Malformed URL path');
      else err(res, 500, 'INTERNAL', 'Internal server error'); // details stay in the server log, never leak to clients
    }
  }
});
const PORT = parseInt(process.env.PORT || '8080', 10);
server.listen(PORT, () => console.log(`HERO DRAMA backend listening on http://localhost:${PORT} (firebase dev: ${process.env.FIREBASE_AUTH_DEV || '0'})`));
