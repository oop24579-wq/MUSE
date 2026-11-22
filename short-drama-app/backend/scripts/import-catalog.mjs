#!/usr/bin/env node
/**
 * import-catalog.mjs — HeroDrama library catalog → backend seed JSON.
 *
 * Reads a CSV in the exact shape of the HeroDrama library catalog
 * (~/workspace/herodrama/HeroDrama_library_catalog.csv):
 *
 *   Type,Series,Item,Google Drive ID,Status (2026-11-22)
 *   Poster,,Poster 001,<drive-id>,Published
 *   Video,Series_01,EP001,<drive-id>,Published
 *
 * and emits a seed JSON the backend can load later:
 *   { generatedFrom, generatedAt, posters: [...], series: [...] }
 *
 * TOOLING ONLY: it never downloads media, never touches any database, and
 * (with --dry-run) writes nothing at all — it just prints counts.
 *
 * Usage:
 *   node scripts/import-catalog.mjs --csv <path> [--out <path>] [--dry-run]
 *   node scripts/import-catalog.mjs --dry-run            (default CSV path)
 *
 * Notes:
 *  - The catalog carries no human titles (posters are numbered, series are
 *    "Series_01".."Series_04"), so series entries get slug/title from the
 *    source name and `titleIsPlaceholder: true` — a human should rename them
 *    in the admin dashboard after import.
 *  - Drive IDs are carried through verbatim; turning them into streamable
 *    URLs is a hosting decision (CDN), deliberately NOT done here.
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const opt = (name, dflt) => { const i = args.indexOf(name); return i >= 0 && args[i + 1] ? args[i + 1] : dflt; };
const csvPath = opt('--csv', path.join(os.homedir(), 'workspace/herodrama/HeroDrama_library_catalog.csv'));
const outPath = opt('--out', path.join(process.cwd(), 'catalog-seed.json'));
const dryRun = flag('--dry-run');

/** Minimal CSV parser: handles BOM, CRLF, quoted fields with embedded commas/quotes. */
function parseCsv(text) {
  const rows = [];
  let row = []; let field = ''; let inQuotes = false;
  const s = text.replace(/^﻿/, '');
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (inQuotes) {
      if (c === '"') { if (s[i + 1] === '"') { field += '"'; i++; } else inQuotes = false; }
      else field += c;
    } else if (c === '"') inQuotes = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && s[i + 1] === '\n') i++;
      row.push(field); field = '';
      if (row.length > 1 || row[0] !== '') rows.push(row);
      row = [];
    } else field += c;
  }
  if (field !== '' || row.length) { row.push(field); rows.push(row); }
  return rows;
}

if (!fs.existsSync(csvPath)) { console.error(`CSV not found: ${csvPath}`); process.exit(1); }
const rows = parseCsv(fs.readFileSync(csvPath, 'utf8'));
const header = rows[0].map((h) => h.trim().toLowerCase());
const col = {
  type: header.findIndex((h) => h === 'type'),
  series: header.findIndex((h) => h === 'series'),
  item: header.findIndex((h) => h === 'item'),
  driveId: header.findIndex((h) => h.includes('drive') && h.includes('id')),
  status: header.findIndex((h) => h.startsWith('status')),
};
if (col.type < 0 || col.item < 0 || col.driveId < 0) {
  console.error('CSV header does not match the expected catalog shape:', rows[0].join(','));
  process.exit(1);
}

const posters = [];
const seriesMap = new Map();
const statusCounts = {};
let skipped = 0;
for (const r of rows.slice(1)) {
  const type = (r[col.type] || '').trim();
  const item = (r[col.item] || '').trim();
  const driveId = (r[col.driveId] || '').trim();
  const status = col.status >= 0 ? (r[col.status] || '').trim() : '';
  if (!type || !driveId) { skipped++; continue; }
  if (status) statusCounts[status] = (statusCounts[status] || 0) + 1;
  if (type === 'Poster') {
    const m = /(\d+)/.exec(item);
    posters.push({ index: m ? parseInt(m[1], 10) : posters.length + 1, label: item, driveId, status });
  } else if (type === 'Video') {
    const seriesName = (r[col.series] || '').trim() || 'Series_Unknown';
    const ep = /EP(\d+)/i.exec(item);
    if (!seriesMap.has(seriesName)) {
      const slug = seriesName.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
      seriesMap.set(seriesName, { slug, sourceName: seriesName, title: seriesName, titleIsPlaceholder: true, episodes: [] });
    }
    seriesMap.get(seriesName).episodes.push({
      episodeNumber: ep ? parseInt(ep[1], 10) : seriesMap.get(seriesName).episodes.length + 1,
      label: item, driveId, status,
    });
  } else skipped++;
}
posters.sort((a, b) => a.index - b.index);
const series = [...seriesMap.values()].sort((a, b) => a.sourceName.localeCompare(b.sourceName));
for (const s of series) s.episodes.sort((a, b) => a.episodeNumber - b.episodeNumber);

console.log(`Catalog: ${csvPath}`);
console.log(`Posters: ${posters.length}`);
for (const s of series) console.log(`  ${s.sourceName}: ${s.episodes.length} episodes`);
console.log(`Total videos: ${series.reduce((n, s) => n + s.episodes.length, 0)}`);
console.log(`Statuses: ${Object.entries(statusCounts).map(([k, v]) => `${k}=${v}`).join(', ') || 'n/a'}`);
if (skipped) console.log(`Skipped rows: ${skipped}`);

if (dryRun) {
  console.log('DRY RUN — nothing written.');
} else {
  const out = {
    generatedFrom: path.basename(csvPath),
    generatedAt: new Date().toISOString(),
    note: 'Drive IDs only — no media downloaded. Series titles are placeholders from the catalog source names.',
    posters, series,
  };
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2) + '\n');
  console.log(`Wrote seed JSON: ${outPath}`);
}
