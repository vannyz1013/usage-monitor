# Usage monitor

A small always-on-top Windows widget for your AI plan limits, and when your subscriptions renew.

## What it shows
| Row | Meaning |
|---|---|
| **5h** | Claude / Codex session limit used, and when it resets |
| **7d** | Weekly limit used, and when it resets |
| **mo** | Estimated % of your billing month, and **Renews** (green) or **Ends** (red) on your pay day |
| **Spotify** | Renews / Ends date |

## Everything is optional
You don't need all of Claude, Codex and Spotify. The widget only shows what this PC has:

| You have | You see |
|---|---|
| Claude Code and/or Codex, logged in or used on this PC | Their 5h and 7d rows |
| A pay day for Claude / Codex in `billing.json` | Their **mo** row. Without one, the month row is left out |
| A `spotify` entry in `billing.json` | The Spotify line. Without one, it isn't shown |
| None of these | A one-line hint |

If you only have one of Claude or Codex, clicking the butterfly to pick the other still shows the one you have.

## Set up
Needs Windows, Node.js and [ccusage](https://github.com/ryoppippi/ccusage) (for the token counts).

1. **Pay days:** copy `billing.example.json` to `billing.json`.
   - Keep only the plans you pay for; delete the others.
   - `payDay` is the day of the month you're billed.
   - `cancels: true` means the plan is set to end instead of renewing.
   - `billing.json` is git-ignored, so your details stay local.
2. **Run it:** double-click `start-widget.vbs`.

```json
{
  "claude": { "payDay": 5, "cancels": false },
  "spotify": { "payDay": 10, "cancels": true, "name": "Spotify", "price": "$11.99" }
}
```

## Controls
- **Move it:** drag.
- **Buttons:** ⟳ refreshes; ✕ shrinks it to the butterfly.
- **Choose what to show:** click the butterfly for Claude / Codex / both; hold it to switch between horizontal, vertical and square.
- **Exit:** right-click → Exit.

## About the month %
Claude and Codex have no monthly limit.
- **The estimate:** the month % is measured against your weekly limit × the weeks in your billing month. It uses this week's tokens (from ccusage) and weekly % to work out how many tokens 1% is.
- **Why "~":** it's an estimate, so it always has a "~" in front.

## Files
| File | Job |
|---|---|
| `widget.ps1` | The window, layouts, mouse and polling |
| `usage-json.js` | Collects everything below into one JSON for the widget |
| `lib/usage.js`, `lib/live.js`, `lib/claude.js`, `lib/codex.js`, `lib/window.js` | 5h / 7d limits (live API, with local fallbacks) |
| `lib/tokens.js` | Token counts from ccusage |
| `lib/billing.js` | Reads `billing.json` |
| `lib/month.js`, `lib/month.ps1` | Billing month and its % estimate; drawing the mo row |
| `lib/spotify.js`, `lib/spotify.ps1` | Spotify's Renews / Ends line |
| `lib/plan-status.ps1` | The green Renews / red Ends label |
| `lib/products.ps1` | Which products to show |
| `statusline.js`, `lib/format.js` | The same usage in the Claude Code status line |
