#!/usr/bin/env node
// Claude Code statusLine command: reads the session JSON on stdin, prints one line.
const { saveClaudeLimits, readClaudeUsage } = require('./lib/claude');
const { readCodexUsage } = require('./lib/codex');
const { formatUsage } = require('./lib/format');

let input = '';
process.stdin.on('data', (d) => (input += d));
process.stdin.on('end', () => {
  let data = {};
  try { data = JSON.parse(input.replace(/^﻿/, '')); } catch {}

  saveClaudeLimits(data.rate_limits);
  const model = data.model && data.model.display_name ? `[${data.model.display_name}] ` : '';
  const claude = formatUsage('Claude', readClaudeUsage(data.rate_limits));
  const codex = formatUsage('Codex', readCodexUsage());
  process.stdout.write(`${model}${claude}  |  ${codex}`);
});
