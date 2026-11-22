'use strict';
/**
 * Captions & translation pipeline — audio-based, like Facebook's auto-translate:
 *   video audio --ASR--> original-language timed segments --MT--> translated segments --render--> WebVTT
 * There are NO per-video subtitle uploads; tracks are generated from the audio.
 *
 * Providers are chosen by the settings store:
 *   asr_provider: 'demo' (default) | 'openai' | 'local-whisper'
 *   mt_provider:  'demo' (default) | 'deepl'  | 'google'
 *
 * DEMO MODE (the default): the demo ASR invents plausible-but-FAKE caption text
 * derived from the episode title/description, and the demo MT only prefixes each
 * cue with a "[<lang>] " tag without actually translating. Plug in real provider
 * keys (OPENAI_API_KEY / DEEPL_API_KEY / GOOGLE_TRANSLATE_API_KEY / WHISPER_CMD)
 * and switch the provider settings for production output.
 */
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { all, get, run } = require('./db');
const auth = require('./auth');
const settings = require('./settings');

const now = () => new Date().toISOString();

// ---------------------------------------------------------------- WebVTT ----
function fmtTime(sec) {
  const ms = Math.max(0, Math.round(sec * 1000));
  const h = String(Math.floor(ms / 3600000)).padStart(2, '0');
  const m = String(Math.floor((ms % 3600000) / 60000)).padStart(2, '0');
  const s = String(Math.floor((ms % 60000) / 1000)).padStart(2, '0');
  const milli = String(ms % 1000).padStart(3, '0');
  return `${h}:${m}:${s}.${milli}`;
}
function renderVtt(segments) {
  let out = 'WEBVTT\n\n';
  for (const seg of segments) out += `${fmtTime(seg.start)} --> ${fmtTime(seg.end)}\n${seg.text}\n\n`;
  return out;
}

// ------------------------------------------------------------- Demo ASR -----
// DEMO PLACEHOLDER: deterministic generator producing plausible-but-fake text
// from the episode title/description. It does NOT listen to the audio at all.
function demoAsrSegments(episode) {
  const title = episode.title || 'Episode';
  const desc = (episode.description || '').trim();
  let lines = desc.split(/(?<=[.!?])\s+/).map((s) => s.trim()).filter(Boolean);
  const templates = [
    `${title} — the story continues.`,
    'You have no idea what is coming next.',
    'Wait. Did you hear that?',
    'I never wanted it to end like this.',
    'Everything changes from this moment on.',
    'Tell me the truth. All of it.',
    'She turned around and froze.',
    'This was never part of the plan.',
    'Some secrets are better left buried.',
    'He had been waiting for this day.',
    'The door opened, and nobody spoke.',
    'To be continued...',
  ];
  let ti = 0;
  while (lines.length < 8) lines.push(templates[ti++ % templates.length]);
  lines = lines.slice(0, 14);
  return lines.map((text, i) => {
    const dur = 3 + (i % 2); // 3-4s cues
    return { start: i * 3.5, end: i * 3.5 + dur, text };
  });
}

// ------------------------------------------------------------------ ASR -----
async function downloadToTemp(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to download video for ASR (HTTP ${res.status})`);
  const buf = Buffer.from(await res.arrayBuffer());
  const file = path.join(os.tmpdir(), `hd-asr-${auth.uid()}.mp4`);
  fs.writeFileSync(file, buf);
  return file;
}

async function asrSegments(episode) {
  const provider = settings.getSetting('asr_provider');
  if (provider === 'openai') {
    const key = process.env.OPENAI_API_KEY;
    if (!key) throw new Error('asr_provider=openai but OPENAI_API_KEY is not set');
    if (!episode.videoUrl) throw new Error('Episode has no videoUrl to transcribe');
    const file = await downloadToTemp(episode.videoUrl);
    try {
      const form = new FormData();
      form.append('file', new Blob([fs.readFileSync(file)], { type: 'video/mp4' }), 'video.mp4');
      form.append('model', 'whisper-1');
      form.append('response_format', 'verbose_json');
      const res = await fetch('https://api.openai.com/v1/audio/transcriptions', {
        method: 'POST', headers: { Authorization: `Bearer ${key}` }, body: form,
      });
      if (!res.ok) throw new Error(`OpenAI transcription failed (HTTP ${res.status}): ${(await res.text()).slice(0, 200)}`);
      const json = await res.json();
      const segs = (json.segments || []).map((s) => ({ start: s.start, end: s.end, text: String(s.text || '').trim() })).filter((s) => s.text);
      if (!segs.length && json.text) return [{ start: 0, end: 4, text: String(json.text).trim() }];
      if (!segs.length) throw new Error('OpenAI transcription returned no segments');
      return segs;
    } finally { try { fs.unlinkSync(file); } catch { /* ignore */ } }
  }
  if (provider === 'local-whisper') {
    const cmd = process.env.WHISPER_CMD;
    if (!cmd) throw new Error('asr_provider=local-whisper but WHISPER_CMD is not set');
    if (!episode.videoUrl) throw new Error('Episode has no videoUrl to transcribe');
    const file = await downloadToTemp(episode.videoUrl);
    try {
      const rendered = cmd.replace('{file}', file);
      const parts = rendered.split(/\s+/).filter(Boolean);
      const outJson = await new Promise((resolve, reject) => {
        const child = spawn(parts[0], parts.slice(1), { stdio: ['ignore', 'pipe', 'pipe'] });
        let err = '';
        child.stderr.on('data', (d) => { err += d; });
        child.on('error', reject);
        child.on('close', (code) => {
          if (code !== 0) return reject(new Error(`WHISPER_CMD exited with code ${code}: ${err.slice(0, 200)}`));
          const jsonFile = file.replace(/\.[^.]+$/, '.json');
          try { resolve(JSON.parse(fs.readFileSync(jsonFile, 'utf8'))); }
          catch (e) { reject(new Error('Could not read whisper JSON output: ' + e.message)); }
        });
      });
      const segs = (outJson.segments || []).map((s) => ({ start: s.start, end: s.end, text: String(s.text || '').trim() })).filter((s) => s.text);
      if (!segs.length) throw new Error('local-whisper returned no segments');
      return segs;
    } finally { try { fs.unlinkSync(file); } catch { /* ignore */ } }
  }
  // 'demo' (default)
  return demoAsrSegments(episode);
}

// ------------------------------------------------------------------- MT -----
async function translateSegments(segments, lang) {
  const provider = settings.getSetting('mt_provider');
  if (provider === 'deepl') {
    const key = process.env.DEEPL_API_KEY;
    if (!key) throw new Error('mt_provider=deepl but DEEPL_API_KEY is not set');
    const params = new URLSearchParams();
    segments.forEach((s) => params.append('text', s.text));
    params.append('target_lang', lang.toUpperCase());
    const res = await fetch('https://api-free.deepl.com/v2/translate', {
      method: 'POST', headers: { Authorization: `DeepL-Auth-Key ${key}`, 'Content-Type': 'application/x-www-form-urlencoded' }, body: params,
    });
    if (!res.ok) throw new Error(`DeepL translate failed (HTTP ${res.status})`);
    const json = await res.json();
    return segments.map((s, i) => ({ ...s, text: (json.translations && json.translations[i] && json.translations[i].text) || s.text }));
  }
  if (provider === 'google') {
    const key = process.env.GOOGLE_TRANSLATE_API_KEY;
    if (!key) throw new Error('mt_provider=google but GOOGLE_TRANSLATE_API_KEY is not set');
    const res = await fetch(`https://translation.googleapis.com/language/translate/v2?key=${encodeURIComponent(key)}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ q: segments.map((s) => s.text), target: lang, format: 'text' }),
    });
    if (!res.ok) throw new Error(`Google Translate failed (HTTP ${res.status})`);
    const json = await res.json();
    const trs = (json.data && json.data.translations) || [];
    return segments.map((s, i) => ({ ...s, text: (trs[i] && trs[i].translatedText) || s.text }));
  }
  // 'demo' (default) DEMO PLACEHOLDER: pass-through text prefixed with a language tag.
  return segments.map((s) => ({ ...s, text: `[${lang}] ${s.text}` }));
}

// --------------------------------------------------------------- Tracks -----
function upsertTrack(episodeId, lang, source, status, vtt) {
  const existing = get('SELECT * FROM caption_tracks WHERE episodeId=? AND lang=?', episodeId, lang);
  if (existing) {
    run('UPDATE caption_tracks SET source=?, status=?, vtt=COALESCE(?,vtt) WHERE id=?', source, status, vtt || null, existing.id);
    return existing.id;
  }
  const id = auth.uid();
  run('INSERT INTO caption_tracks(id,episodeId,lang,source,status,vtt,createdAt) VALUES(?,?,?,?,?,?,?)', id, episodeId, lang, source, status, vtt || null, now());
  return id;
}
function setTrackStatus(episodeId, lang, status) {
  run('UPDATE caption_tracks SET status=? WHERE episodeId=? AND lang=?', status, episodeId, lang);
}
function readyLanguages(episodeId) {
  if (!settings.getSetting('captions_enabled')) return [];
  return all("SELECT lang FROM caption_tracks WHERE episodeId=? AND status='ready' ORDER BY lang", episodeId).map((r) => r.lang);
}

/** Synchronous demo generation (used by the seed so tracks exist deterministically). */
function generateDemoTracksSync(episodeId, targets) {
  const episode = get('SELECT * FROM episodes WHERE id=?', episodeId);
  if (!episode) return;
  const langs = targets && targets.length ? targets : settings.getSetting('caption_target_languages');
  const segments = demoAsrSegments(episode);
  upsertTrack(episodeId, 'orig', 'asr', 'ready', renderVtt(segments));
  for (const lang of langs) {
    if (lang === 'orig') continue;
    const translated = segments.map((s) => ({ ...s, text: `[${lang}] ${s.text}` })); // demo MT placeholder
    upsertTrack(episodeId, lang, 'mt', 'ready', renderVtt(translated));
  }
}

// --------------------------------------------------------------- Worker -----
let workerRunning = false;
const jobTargets = new Map(); // jobId -> target langs (not persisted; defaults re-read if lost)

function enqueueCaptionJob(episodeId, targets) {
  const langs = targets && targets.length ? targets : settings.getSetting('caption_target_languages');
  const jobId = auth.uid();
  run("INSERT INTO caption_jobs(id,episodeId,status,step,createdAt) VALUES(?,?,'queued','queued',?)", jobId, episodeId, now());
  jobTargets.set(jobId, langs);
  upsertTrack(episodeId, 'orig', 'asr', 'queued', null);
  for (const lang of langs) if (lang !== 'orig') upsertTrack(episodeId, lang, 'mt', 'queued', null);
  kickWorker();
  return jobId;
}

function kickWorker() {
  if (workerRunning) return;
  workerRunning = true;
  (async () => {
    try {
      for (;;) {
        const job = get("SELECT * FROM caption_jobs WHERE status='queued' ORDER BY createdAt ASC LIMIT 1");
        if (!job) break;
        await processJob(job.id);
      }
    } catch (e) { console.error('[captions] worker error', e); }
    finally { workerRunning = false; }
  })();
}

async function processJob(jobId) {
  const job = get('SELECT * FROM caption_jobs WHERE id=?', jobId);
  if (!job) return;
  const episode = get('SELECT * FROM episodes WHERE id=?', job.episodeId);
  const targets = jobTargets.get(jobId) || settings.getSetting('caption_target_languages');
  try {
    if (!episode) throw new Error('Episode not found');
    run("UPDATE caption_jobs SET status='processing', step='asr' WHERE id=?", jobId);
    setTrackStatus(job.episodeId, 'orig', 'processing');
    const segments = await asrSegments(episode);
    upsertTrack(job.episodeId, 'orig', 'asr', 'ready', renderVtt(segments));
    run("UPDATE caption_jobs SET step='mt' WHERE id=?", jobId);
    for (const lang of targets) {
      if (lang === 'orig') continue;
      setTrackStatus(job.episodeId, lang, 'processing');
      const translated = await translateSegments(segments, lang);
      upsertTrack(job.episodeId, lang, 'mt', 'ready', renderVtt(translated));
    }
    run("UPDATE caption_jobs SET status='done', step='done', finishedAt=? WHERE id=?", now(), jobId);
  } catch (e) {
    const msg = e && e.message ? e.message : String(e);
    try {
      run("UPDATE caption_jobs SET status='failed', step='failed', error=?, finishedAt=? WHERE id=?", msg, now(), jobId);
      run("UPDATE caption_tracks SET status='failed' WHERE episodeId=? AND status IN ('queued','processing')", job.episodeId);
    } catch { /* never throw uncaught from the worker */ }
  } finally {
    jobTargets.delete(jobId);
  }
}

module.exports = {
  renderVtt, demoAsrSegments, generateDemoTracksSync,
  enqueueCaptionJob, processJob, kickWorker, readyLanguages, upsertTrack,
};
