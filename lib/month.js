// Billing month: runs from the day of the month you pay (lib/billing.js) to the same day next month,
// plus an estimated % of that month's allowance used (no provider has a real monthly limit).
const fs = require('fs');
const os = require('os');
const path = require('path');

// Tokens-per-1% learned from a week with enough usage, kept so a freshly reset week can still estimate.
const RATE_FILE = path.join(os.homedir(), '.claude', 'usage-month-rate.json');
const MIN_WEEK_PCT = 10;

// Plan limits track compute, not raw tokens: cache reads are cheap, output is dear. These are the providers'
// API price ratios relative to input, used only to weigh tokens against each other for the estimate.
const WEIGHT = { input: 1, output: 5, cacheCreation: 1.25, cacheRead: 0.1 };
const weighted = (m) => (m.inputTokens || 0) * WEIGHT.input + (m.outputTokens || 0) * WEIGHT.output
  + (m.cacheCreationTokens || 0) * WEIGHT.cacheCreation + (m.cacheReadTokens || 0) * WEIGHT.cacheRead;

const ymd = (d, sep = '') =>
  [d.getFullYear(), String(d.getMonth() + 1).padStart(2, '0'), String(d.getDate()).padStart(2, '0')].join(sep);

// Pay day 31 in a 30-day month falls on the 30th.
function dayIn(year, month, day) {
  return new Date(year, month, Math.min(day, new Date(year, month + 1, 0).getDate()));
}

// { start, end } of the billing month containing now (start inclusive, end = next pay day).
function billingCycle(payDay, now = new Date()) {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  let start = dayIn(now.getFullYear(), now.getMonth(), payDay);
  if (start > today) start = dayIn(now.getFullYear(), now.getMonth() - 1, payDay);
  return { start, end: dayIn(start.getFullYear(), start.getMonth() + 1, payDay) };
}

// Estimated % of the billing month's allowance used, taking the allowance as the weekly limit times the
// weeks in the billing month. The weekly limit's size in tokens comes from this week: its tokens / its %.
// days: { 'YYYY-MM-DD': weighted tokens }. null if it can't tell.
function monthPercent(agent, month, days, weekly) {
  if (!month) return null;
  let rates = {};
  try { rates = JSON.parse(fs.readFileSync(RATE_FILE, 'utf8')); } catch {}
  let rate = rates[agent] || null;
  if (weekly && weekly.resetsAt && weekly.pct >= MIN_WEEK_PCT) {
    // The week's first day only counts for the hours after it began (as if spread evenly over the day).
    const startAt = new Date((weekly.resetsAt - 7 * 86400) * 1000);
    const weekStart = ymd(startAt, '-');
    const firstDayShare = 1 - (startAt.getHours() + startAt.getMinutes() / 60) / 24;
    const weekTokens = Object.entries(days).reduce(
      (s, [p, w]) => s + (p > weekStart ? w : p === weekStart ? w * firstDayShare : 0), 0);
    if (weekTokens > 0) {
      rate = weekTokens / weekly.pct;
      rates[agent] = rate;
      try { fs.writeFileSync(RATE_FILE, JSON.stringify(rates)); } catch {}
    }
  }
  if (!rate) return null;
  const cycleDays = (Date.parse(month.end) - Date.parse(month.start)) / 86400000;
  return Math.round((month.weighted / (rate * 100 * cycleDays / 7)) * 100);
}

module.exports = { ymd, weighted, billingCycle, monthPercent };
