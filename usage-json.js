#!/usr/bin/env node
// Prints both usages as JSON; the desktop widget polls this.
// Every usage carries asOf (unix s): the widget greys out anything too old.
const { readClaudeUsage } = require('./lib/claude');
const { readCodexUsage } = require('./lib/codex');
const { liveClaudeUsage, liveCodexUsage } = require('./lib/live');
const { readTodayTokens } = require('./lib/tokens');
const { laterWindow } = require('./lib/window');

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

(async () => {
  const [claude, codex] = await Promise.all([liveClaudeUsage(), liveCodexUsage()]);
  const tokens = readTodayTokens() || {};
  process.stdout.write(JSON.stringify({
    claude: newest(claude, readClaudeUsage()),
    codex: newest(codex, readCodexUsage()),
    tokens: { claude: tokens.claude || null, codex: tokens.codex || null },
  }));
})();
