// Codex plan usage, read from the newest rate_limits event in ~/.codex/sessions/**/rollout-*.jsonl.
const fs = require('fs');
const path = require('path');
const os = require('os');
const { makeWindow } = require('./window');

const SESSIONS = path.join(process.env.CODEX_HOME || path.join(os.homedir(), '.codex'), 'sessions');

// Newest session files first, walking sessions/YYYY/MM/DD in reverse name order.
function newestSessionFiles(limit) {
  const out = [];
  const walk = (dir) => {
    let entries;
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
    entries.sort((a, b) => b.name.localeCompare(a.name));
    for (const e of entries) {
      if (out.length >= limit) return;
      const p = path.join(dir, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name.endsWith('.jsonl')) out.push(p);
    }
  };
  walk(SESSIONS);
  return out.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
}

function lastRateLimits(file) {
  let lines;
  try { lines = fs.readFileSync(file, 'utf8').split('\n'); } catch { return null; }
  for (let i = lines.length - 1; i >= 0; i--) {
    if (!lines[i].includes('"rate_limits"')) continue;
    try {
      const rl = JSON.parse(lines[i]).payload.rate_limits;
      if (rl && rl.primary) return rl;
    } catch {}
  }
  return null;
}

function readCodexUsage() {
  for (const file of newestSessionFiles(5)) {
    const rl = lastRateLimits(file);
    if (!rl) continue;
    return {
      fiveHour: makeWindow(rl.primary.used_percent, rl.primary.resets_at),
      weekly: rl.secondary ? makeWindow(rl.secondary.used_percent, rl.secondary.resets_at) : null,
      plan: rl.plan_type || null,
      asOf: fs.statSync(file).mtimeMs / 1000,
    };
  }
  return null;
}

module.exports = { readCodexUsage };
