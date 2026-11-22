'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { seed } = require('./seed');
const { handle, adminHandle, err } = require('./routes');
seed();
const ADMIN_DIR = path.join(__dirname, '..', 'public', 'admin');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.svg': 'image/svg+xml' };
function readBody(req) {
  return new Promise((resolve) => {
    let data = ''; req.on('data', (c) => { data += c; if (data.length > 5e6) req.destroy(); });
    req.on('end', () => { if (!data) return resolve({}); try { resolve(JSON.parse(data)); } catch { resolve({}); } });
    req.on('error', () => resolve({}));
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
      if (!file.startsWith(ADMIN_DIR) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
        res.writeHead(404, { 'Content-Type': 'text/plain' }); return res.end('Not found');
      }
      res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
      return fs.createReadStream(file).pipe(res);
    }
    if (url.pathname.startsWith('/api/v1/admin/')) { const body = await readBody(req); return adminHandle(req, res, url, body); }
    if (url.pathname.startsWith('/api/v1/')) { const body = await readBody(req); return await handle(req, res, url, body); }
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: { code: 'NOT_FOUND', message: 'Not found' } }));
  } catch (e) { console.error(e); if (!res.headersSent) err(res, 500, 'INTERNAL', e.message); }
});
const PORT = parseInt(process.env.PORT || '8080', 10);
server.listen(PORT, () => console.log(`HERO DRAMA backend listening on http://localhost:${PORT} (admin token: ${process.env.ADMIN_TOKEN || 'dev-admin-token-change-me'}, firebase dev: ${process.env.FIREBASE_AUTH_DEV || '0'})`));
