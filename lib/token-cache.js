// A short-lived cache for the ccusage run in lib/tokens.js.
// The widget polls once a minute, and every poll was a fresh `ccusage daily --offline` over every local Claude
// and Codex log. The plan limits it feeds (the mo row, and the tokens-per-1% the month estimate learns from)
// move slowly, so re-reading all of that every 60 s is work for nothing.
//
// Cached for 5 minutes, and thrown away early if the day or billing.json changed underneath it. The ⟳ button
// and right-click -> Refresh now pass fresh = true and skip it, so "refresh" always means refresh.
const fs = require('fs');
const os = require('os');
const path = require('path');

const CACHE = path.join(os.homedir(), '.claude', 'usage-tokens-cache.json');
const MAX_AGE_MS = 5 * 60 * 1000;

// key: anything that must invalidate the cache when it changes (the date, and the pay days).
// build(): the expensive call. Its result is cached only if it isn't null - a failed ccusage run
// shouldn't be remembered for five minutes.
function cached(key, fresh, build) {
  if (!fresh) {
    try {
      const c = JSON.parse(fs.readFileSync(CACHE, 'utf8'));
      if (c && c.key === key && Date.now() - c.at < MAX_AGE_MS) return c.data;
    } catch {}
  }
  const data = build();
  if (data) {
    try { fs.writeFileSync(CACHE, JSON.stringify({ key, at: Date.now(), data })); } catch {}
  }
  return data;
}

module.exports = { cached };
