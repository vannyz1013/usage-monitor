// Spotify subscription: no usage data, just the next pay day and whether the plan renews or ends.
// From the "spotify" entry of billing.json (lib/billing.js), e.g.
//   "spotify": { "payDay": 10, "cancels": false, "name": "Spotify", "price": "$11.99" }
const { readBilling } = require('./billing');
const { ymd, billingCycle } = require('./month');

// { name, price, cancels, next: 'YYYY-MM-DD' }, or null if billing.json has no Spotify entry.
function readSpotify(now = new Date()) {
  const b = readBilling().spotify;
  if (!b) return null;
  return {
    name: b.name === 'spotify' ? 'Spotify' : b.name,
    price: b.price,
    cancels: b.cancels,
    next: ymd(billingCycle(b.payDay, now).end, '-'),
  };
}

module.exports = { readSpotify };
