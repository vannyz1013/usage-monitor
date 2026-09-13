// One-line, ANSI-coloured rendering for the Claude Code status line.
// Same content as the widget bar: "5h 15% ↻7:30AM · 7d 45% ↻Fri 3:00AM".

const STALE_S = 360; // same as the widget: older numbers are last-known, not live

// Reset clock time, like the widget: "7:30AM" for the session, "Fri 3:00AM" for the week.
function formatReset(resetsAt, weekly) {
  if (!resetsAt) return '';
  const d = new Date(resetsAt * 1000);
  const h = d.getHours() % 12 || 12;
  const time = `${h}:${String(d.getMinutes()).padStart(2, '0')}${d.getHours() < 12 ? 'AM' : 'PM'}`;
  return weekly ? `${d.toLocaleDateString('en-US', { weekday: 'short' })} ${time}` : time;
}

function colour(pct, stale, text) {
  const code = stale ? 90 : pct >= 90 ? 31 : pct >= 70 ? 33 : 32;
  return `\x1b[${code}m${text}\x1b[0m`;
}

function formatWindow(label, w, weekly, stale) {
  if (!w) return `${label} —`;
  const reset = w.resetsAt ? ` ↻${formatReset(w.resetsAt, weekly)}` : '';
  return colour(w.pct, stale, `${label} ${w.pct}%${stale ? '?' : ''}`) + reset;
}

function formatUsage(name, usage, now = Date.now() / 1000) {
  if (!usage) return `${name} —`;
  const stale = !usage.asOf || now - usage.asOf > STALE_S;
  return `${name} ${formatWindow('5h', usage.fiveHour, false, stale)} · ${formatWindow('7d', usage.weekly, true, stale)}`;
}

module.exports = { formatReset, formatUsage };
