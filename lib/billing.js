// Your subscriptions, from billing.json (git-ignored; copy billing.example.json):
//   { "claude": { "payDay": 5, "cancels": true }, "codex": { "payDay": 12, "cancels": false },
//     "spotify": { "payDay": 10, "cancels": false, "name": "Spotify", "price": "$11.99" } }
// payDay: day of the month you pay. cancels: true if the plan is set to end at the next pay day instead of renewing
// (claude.ai → Settings → Billing, chatgpt.com → Settings → Account). name / price: optional labels, used for
// plans without usage data (lib/spotify.js). Nothing here is read from the providers.
// The old form { "claude": 22 } still works and means "renews".
const fs = require('fs');
const path = require('path');

const BILLING_FILE = path.join(__dirname, '..', 'billing.json');

// { claude: { payDay, cancels, name, price }, ... }; an entry without a valid pay day is left out.
function readBilling() {
  let raw;
  try { raw = JSON.parse(fs.readFileSync(BILLING_FILE, 'utf8')); } catch { return {}; }
  const out = {};
  for (const [agent, v] of Object.entries(raw || {})) {
    const payDay = typeof v === 'number' ? v : v && v.payDay;
    if (Number.isInteger(payDay) && payDay >= 1 && payDay <= 31) {
      out[agent] = { payDay, cancels: Boolean(v && v.cancels), name: (v && v.name) || agent, price: (v && v.price) || null };
    }
  }
  return out;
}

module.exports = { readBilling };
