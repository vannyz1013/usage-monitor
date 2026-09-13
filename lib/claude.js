// Claude plan usage. Claude Code only exposes rate_limits in the status line input,
// so the status line caches it here and the widget reads the cache.
const fs = require('fs');
const path = require('path');
const os = require('os');
const { makeWindow } = require('./window');

const CACHE = path.join(os.homedir(), '.claude', 'usage-cache.json');

function saveClaudeLimits(rateLimits) {
  if (!rateLimits) return;
  try {
    fs.writeFileSync(CACHE, JSON.stringify({ rate_limits: rateLimits, saved_at: Date.now() / 1000 }));
  } catch {}
}

function readClaudeUsage(rateLimits) {
  let src = rateLimits;
  let asOf = Date.now() / 1000;
  if (!src) {
    try { ({ rate_limits: src, saved_at: asOf } = JSON.parse(fs.readFileSync(CACHE, 'utf8'))); } catch {}
  }
  if (!src) return null;
  const w = (k) => (src[k] ? makeWindow(src[k].used_percentage, src[k].resets_at) : null);
  return { fiveHour: w('five_hour'), weekly: w('seven_day'), asOf };
}

module.exports = { saveClaudeLimits, readClaudeUsage };
