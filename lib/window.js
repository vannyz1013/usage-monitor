// A usage window: { pct, resetsAt } (resetsAt = unix seconds).
// A window whose reset time has passed is back at 0%.
function makeWindow(pct, resetsAt, now = Date.now() / 1000) {
  if (pct == null) return null;
  if (resetsAt && resetsAt < now) return { pct: 0, resetsAt: null };
  return { pct: Math.round(pct), resetsAt: resetsAt || null };
}

// Two readings of the same limit. Within one window usage only rises, so the lower one is stale
// (an idle Claude Code session re-runs its status line with old rate_limits). A later reset is a new window.
// Sources disagree on sub-second reset times, hence the tolerance.
function laterWindow(a, b) {
  if (!a || !b) return a || b;
  if (a.resetsAt && b.resetsAt && Math.abs(a.resetsAt - b.resetsAt) > 600) {
    return a.resetsAt > b.resetsAt ? a : b;
  }
  return a.pct >= b.pct ? a : b;
}

module.exports = { makeWindow, laterWindow };
