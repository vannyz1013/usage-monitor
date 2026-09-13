// Live plan usage straight from the providers, using the tokens Claude Code and Codex already
// keep on disk. Never refreshes tokens itself (that would rotate them under the real CLIs):
// if a token has expired, returns null and the caller falls back to local logs.
const fs = require('fs');
const path = require('path');
const os = require('os');
const { makeWindow } = require('./window');

const HOME = os.homedir();
const TIMEOUT_MS = 8000;
// Each poll is a fresh node process, so throttle state lives on disk:
// { [provider]: { at, body } } last success, and { [provider]: { wait, until } } backoff.
const LAST_FILE = path.join(HOME, '.claude', 'usage-live.json');
const BACKOFF_FILE = path.join(HOME, '.claude', 'usage-backoff.json');
const BACKOFF_MIN_S = 120;
const BACKOFF_MAX_S = 600;
// Claude's usage endpoint 429s at a 20 s cadence, and even at 60 s within ~12 min.
const MIN_INTERVAL_S = { claude: 300, codex: 60 };

function readJson(file) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return null; }
}

// Re-read before writing: Claude and Codex are fetched in parallel and share these files.
function patchJson(file, name, value) {
  const all = readJson(file) || {};
  all[name] = value;
  try { fs.writeFileSync(file, JSON.stringify(all)); } catch {}
}

// Returns { body, at } (at = ms of the fetch), possibly an earlier answer reused, or null.
// Fetches at most every MIN_INTERVAL_S; after a 429 waits 2, 4, … 10 min and reuses the last answer.
// cachedOnly: never touch the network, just reuse the last answer (the status line runs too often to fetch).
async function getJson(name, url, headers, cachedOnly) {
  const last = (readJson(LAST_FILE) || {})[name];
  if (cachedOnly || (last && Date.now() - last.at < MIN_INTERVAL_S[name] * 1000)) return last || null;
  const b = (readJson(BACKOFF_FILE) || {})[name];
  if (b && b.until > Date.now()) return last || null;
  try {
    const res = await fetch(url, { headers, signal: AbortSignal.timeout(TIMEOUT_MS) });
    if (res.status === 429) {
      const wait = b ? Math.min(BACKOFF_MAX_S, b.wait * 2) : BACKOFF_MIN_S;
      patchJson(BACKOFF_FILE, name, { wait, until: Date.now() + wait * 1000 });
      return last || null;
    }
    if (!res.ok) return null;
    const fresh = { at: Date.now(), body: await res.json() };
    patchJson(LAST_FILE, name, fresh);
    if (b) patchJson(BACKOFF_FILE, name, undefined);
    return fresh;
  } catch {
    return null;
  }
}

const toUnix = (iso) => (iso ? Date.parse(iso) / 1000 : null);

async function liveClaudeUsage(cachedOnly) {
  const oauth = (readJson(path.join(HOME, '.claude', '.credentials.json')) || {}).claudeAiOauth;
  if (!oauth || !oauth.accessToken || (oauth.expiresAt && oauth.expiresAt < Date.now())) return null;
  const r = await getJson('claude', 'https://api.anthropic.com/api/oauth/usage', {
    Authorization: `Bearer ${oauth.accessToken}`,
    'anthropic-beta': 'oauth-2025-04-20',
  }, cachedOnly);
  const u = r && r.body;
  if (!u || !u.five_hour) return null;
  const w = (k) => (u[k] ? makeWindow(u[k].utilization, toUnix(u[k].resets_at)) : null);
  return { fiveHour: w('five_hour'), weekly: w('seven_day'), plan: oauth.subscriptionType || null, asOf: r.at / 1000 };
}

async function liveCodexUsage(cachedOnly) {
  const home = process.env.CODEX_HOME || path.join(HOME, '.codex');
  const tokens = (readJson(path.join(home, 'auth.json')) || {}).tokens;
  if (!tokens || !tokens.access_token) return null;
  const r = await getJson('codex', 'https://chatgpt.com/backend-api/wham/usage', {
    Authorization: `Bearer ${tokens.access_token}`,
    'ChatGPT-Account-Id': tokens.account_id || '',
    'User-Agent': 'codex_cli_rs',
  }, cachedOnly);
  const u = r && r.body;
  const rl = u && u.rate_limit;
  if (!rl || !rl.primary_window) return null;
  const w = (x) => (x ? makeWindow(x.used_percent, x.reset_at) : null);
  return { fiveHour: w(rl.primary_window), weekly: w(rl.secondary_window), plan: u.plan_type || null, asOf: r.at / 1000 };
}

module.exports = { liveClaudeUsage, liveCodexUsage };
