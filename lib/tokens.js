// Today's token spend per agent, from ccusage (reads local Claude + Codex logs).
const { execSync } = require('child_process');

function today() {
  const d = new Date();
  return `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}`;
}

function readTodayTokens() {
  let report;
  try {
    const out = execSync(`ccusage daily --json --offline --since ${today()}`, {
      encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 20000, windowsHide: true,
    });
    report = JSON.parse(out);
  } catch {
    return null;
  }

  const empty = () => ({ total: 0, inOut: 0, cache: 0 });
  const result = { claude: empty(), codex: empty() };
  for (const day of report.daily || []) {
    for (const m of day.modelBreakdowns || []) {
      const t = result[m.modelName.startsWith('claude') ? 'claude' : 'codex'];
      const inOut = (m.inputTokens || 0) + (m.outputTokens || 0);
      const cache = (m.cacheCreationTokens || 0) + (m.cacheReadTokens || 0);
      t.inOut += inOut;
      t.cache += cache;
      t.total += inOut + cache;
    }
  }
  return result;
}

module.exports = { readTodayTokens };
