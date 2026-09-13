// A usage window: { pct, resetsAt } (resetsAt = unix seconds).
// A window whose reset time has passed is back at 0%.
function makeWindow(pct, resetsAt, now = Date.now() / 1000) {
  if (pct == null) return null;
  if (resetsAt && resetsAt < now) return { pct: 0, resetsAt: null };
  return { pct: Math.round(pct), resetsAt: resetsAt || null };
}

module.exports = { makeWindow };
