// Claude plan usage. Claude Code only exposes rate_limits in the status line input,
// so the status line caches it here and the widget reads the cache.
const fs = require('fs');
const path = require('path');
const os = require('os');
const { makeWindow, laterWindow } = require('./window');

const CACHE = path.join(os.homedir(), '.claude', 'usage-cache.json');

function readCache() {
  try { return JSON.parse(fs.readFileSync(CACHE, 'utf8')); } catch { return null; }
}

// Several Claude Code sessions share this cache, and an idle one still carries old numbers:
// never let a lower reading of the same window overwrite a higher one.
function saveClaudeLimits(rateLimits) {
  if (!rateLimits) return;
  const old = (readCache() || {}).rate_limits || {};
  const merged = {};
  for (const k of new Set([...Object.keys(old), ...Object.keys(rateLimits)])) {
    const raw = (x) => (x ? { pct: x.used_percentage, resetsAt: x.resets_at, x } : null);
    const win = laterWindow(raw(rateLimits[k]), raw(old[k]));
    if (win) merged[k] = win.x;
  }
  try {
    fs.writeFileSync(CACHE, JSON.stringify({ rate_limits: merged, saved_at: Date.now() / 1000 }));
  } catch {}
}

function readClaudeUsage() {
  const { rate_limits: src, saved_at: asOf } = readCache() || {};
  if (!src) return null;
  const w = (k) => (src[k] ? makeWindow(src[k].used_percentage, src[k].resets_at) : null);
  return { fiveHour: w('five_hour'), weekly: w('seven_day'), asOf };
}

module.exports = { saveClaudeLimits, readClaudeUsage };
