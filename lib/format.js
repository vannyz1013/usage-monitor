// One-line, ANSI-coloured rendering for the Claude Code status line.

function formatReset(resetsAt, now = Date.now() / 1000) {
  if (!resetsAt) return '';
  const mins = Math.max(0, Math.round((resetsAt - now) / 60));
  if (mins < 60) return `${mins}m`;
  if (mins < 60 * 24) return `${Math.floor(mins / 60)}h${String(mins % 60).padStart(2, '0')}`;
  return `${Math.floor(mins / 1440)}d${Math.floor((mins % 1440) / 60)}h`;
}

function colour(pct, text) {
  const code = pct >= 90 ? 31 : pct >= 70 ? 33 : 32;
  return `\x1b[${code}m${text}\x1b[0m`;
}

function formatWindow(label, w) {
  if (!w) return `${label} —`;
  const reset = w.resetsAt ? ` ↻${formatReset(w.resetsAt)}` : '';
  return colour(w.pct, `${label} ${w.pct}%`) + reset;
}

function formatUsage(name, usage) {
  if (!usage) return `${name} —`;
  return `${name} ${formatWindow('5h', usage.fiveHour)} · ${formatWindow('7d', usage.weekly)}`;
}

module.exports = { formatReset, formatUsage };
