// Both plan usages, merged the same way for the widget and the status line.
const { readClaudeUsage } = require('./claude');
const { readCodexUsage } = require('./codex');
const { liveClaudeUsage, liveCodexUsage } = require('./live');
const { laterWindow } = require('./window');

// Live API answers are throttled, so a local snapshot (Claude Code saves one every turn) can be ahead.
// Timestamps can't be trusted to pick one (a stale session writes old numbers "now"), so per window
// take the higher reading. The local snapshot has no plan name, so keep the live one's.
function newest(live, local) {
  if (!live || !local) return live || local;
  return {
    fiveHour: laterWindow(live.fiveHour, local.fiveHour),
    weekly: laterWindow(live.weekly, local.weekly),
    asOf: Math.max(live.asOf || 0, local.asOf || 0),
    plan: live.plan || local.plan || null,
  };
}

// cachedOnly: reuse the widget's last live answers instead of calling the APIs.
async function readUsage(cachedOnly = false) {
  const [claude, codex] = await Promise.all([liveClaudeUsage(cachedOnly), liveCodexUsage(cachedOnly)]);
  return { claude: newest(claude, readClaudeUsage()), codex: newest(codex, readCodexUsage()) };
}

module.exports = { readUsage };
