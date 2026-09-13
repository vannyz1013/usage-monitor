#!/usr/bin/env node
// Prints both usages as JSON; the desktop widget polls this.
// Every usage carries asOf (unix s): the widget greys out anything too old.
const { readUsage } = require('./lib/usage');
const { readTodayTokens } = require('./lib/tokens');

(async () => {
  const usage = await readUsage();
  const tokens = readTodayTokens() || {};
  process.stdout.write(JSON.stringify({
    ...usage,
    tokens: { claude: tokens.claude || null, codex: tokens.codex || null },
  }));
})();
