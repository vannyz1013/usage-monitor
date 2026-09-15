#!/usr/bin/env node
// Prints both usages as JSON; the desktop widget polls this.
// Every usage carries asOf (unix s): the widget greys out anything too old.
const { readUsage } = require('./lib/usage');
const { readTokens } = require('./lib/tokens');
const { monthPercent } = require('./lib/month');
const { readSpotify } = require('./lib/spotify');

(async () => {
  const usage = await readUsage();
  const { today = {}, month = {}, days = {} } = readTokens() || {};
  const withPct = (agent) => {
    const m = month[agent];
    if (!m) return null;
    return { ...m, pct: monthPercent(agent, m, days[agent] || {}, (usage[agent] || {}).weekly) };
  };
  process.stdout.write(JSON.stringify({
    ...usage,
    tokens: { claude: today.claude || null, codex: today.codex || null },
    month: { claude: withPct('claude'), codex: withPct('codex') },
    spotify: readSpotify(),
  }));
})();
