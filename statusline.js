#!/usr/bin/env node
// Claude Code statusLine command: reads the session JSON on stdin, prints one line.
const { saveClaudeLimits } = require('./lib/claude');
const { readUsage } = require('./lib/usage');
const { formatUsage } = require('./lib/format');

let input = '';
process.stdin.on('data', (d) => (input += d));
process.stdin.on('end', async () => {
  let data = {};
  try { data = JSON.parse(input.replace(/^\uFEFF/, '')); } catch {}

  saveClaudeLimits(data.rate_limits);
  const { claude, codex } = await readUsage(true);
  const model = data.model && data.model.display_name ? `[${data.model.display_name}] ` : '';
  process.stdout.write(`${model}${formatUsage('Claude', claude)}  |  ${formatUsage('Codex', codex)}`);
});
