// Token spend per agent from ccusage (reads local Claude + Codex logs): today, and this billing month (lib/month.js).
const { execSync } = require('child_process');
const { ymd, weighted, billingCycle } = require('./month');
const { readBilling } = require('./billing');

const AGENTS = ['claude', 'codex'];

// { today: {claude, codex}, month: {claude, codex}, days: {claude: {period: weighted}, codex} };
// month is null for an agent with no pay day.
function readTokens(now = new Date()) {
  const billing = readBilling();
  const cycles = {};
  // At least a week back, for the weekly window monthPercent measures.
  let since = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 7);
  for (const a of AGENTS) {
    if (!billing[a]) continue;
    cycles[a] = billingCycle(billing[a].payDay, now);
    if (cycles[a].start < since) since = cycles[a].start;
  }

  let report;
  try {
    const out = execSync(`ccusage daily --json --offline --since ${ymd(since)}`, {
      encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 30000, windowsHide: true,
    });
    report = JSON.parse(out);
  } catch {
    return null;
  }

  const empty = () => ({ total: 0, inOut: 0, cache: 0 });
  const add = (t, m) => {
    const inOut = (m.inputTokens || 0) + (m.outputTokens || 0);
    const cache = (m.cacheCreationTokens || 0) + (m.cacheReadTokens || 0);
    t.inOut += inOut;
    t.cache += cache;
    t.total += inOut + cache;
  };
  const today = { claude: empty(), codex: empty() };
  const month = {};
  for (const a of AGENTS) {
    if (cycles[a]) {
      month[a] = { ...empty(), weighted: 0, start: ymd(cycles[a].start, '-'), end: ymd(cycles[a].end, '-'),
        cancels: billing[a].cancels };
    }
  }
  const days = { claude: {}, codex: {} };
  const todayKey = ymd(now, '-');
  for (const day of report.daily || []) {
    for (const m of day.modelBreakdowns || []) {
      const a = m.modelName.startsWith('claude') ? 'claude' : 'codex';
      days[a][day.period] = (days[a][day.period] || 0) + weighted(m);
      if (day.period === todayKey) add(today[a], m);
      if (month[a] && day.period >= month[a].start) {
        add(month[a], m);
        month[a].weighted += weighted(m);
      }
    }
  }
  return { today, month: { claude: month.claude || null, codex: month.codex || null }, days };
}

module.exports = { readTokens };
