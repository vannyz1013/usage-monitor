# Usage monitor

A small always-on-top Windows widget for your AI plan limits, and when your subscriptions renew.

## What it shows
All percentages show **usage consumed**, not the percentage remaining.

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
- **Command Center:** click **Usage settings** (or type `usage-settings`) to choose plans, layout, theme and background. Click **Apply** to save.
- **From your pet:** tap its butterfly clip to show usage; tap again to hide it. This keeps your selected layout. Use the **≡** button on any shape or the tray menu for product and layout controls.
- **On every shape:** the visible **≡** button opens the same menu; drag that button to move the widget. Only this small button catches clicks. The usage readout stays click-through.
- **All shapes:** Mini, Mini + dates, Dashboard, Bar, Pole, Tall panel and Square are click-through overlays. The usage stays visible while clicks go to the app underneath. Only the small **≡** menu button is interactive; drag it to move the current shape.
- **Dashboard:** an optional expanded view. Session and weekly cards show usage and reset countdowns. Choose **Show full dashboard** or select **Dashboard** under **Shape (all click-through)**. Its body remains read-only and click-through.
- **Move it:** drag the **≡** button in any shape. The usage body remains click-through while you move it.
- **Menu:** **Details**, **Refresh now**, **Hide widget**, **Usage settings**, **Show**, **Shape** and **Look** are available from the **≡** button or tray icon.
- **Choose what to show:** use the **Show** menu for Claude / Codex / both, and **Shape** for Mini, Mini + dates, Dashboard, Bar, Pole,
  Tall panel or Square. Every shape is click-through.
- **Details** (reset times, how long until each reset, today's tokens, what `mo` means): right-click → Details.
  Opens a scrollable window you can keep open and copy from.
- **Light or dark:** right-click → Look. "Follow Windows" is the default and changes with your Windows app mode.
- **Too wide?** right-click → Look → Compact bar leaves the `mo` row off the one-line bar (about 1170 px → 790 px).
  The other shapes keep it.
- **First run:** the very first time it starts on a PC it shows a short note about these controls, once.
- **Warnings:** a tray notification the first time each limit passes 80%, and again at 95%. Right-click →
  Warn me near the limit turns it off.
- **Background:** choose Solid or Faded. Every shape is click-through by default, except its small menu button. The usage remains readable while the app underneath stays clickable.
- **Exit:** right-click → Exit.

## Layouts
| | Shape |
|---|---|
| Mini | Small header and one usage row per provider; full details available on right-click |
| Mini + dates | The same compact rows, with each provider's 5h / 7d reset dates and its Renews / Ends date; Spotify is shown underneath when configured |
| Dashboard | Readable usage cards, reset countdowns, renewal dates, product filters and visible controls |
| Horizontal | One line: every product's 5h, 7d and mo rows, then Spotify. No ↻ reset clocks - they made it span the screen. Look → Compact bar drops the mo row too |
| Pole | A narrow stick, everything stacked down it, text upright |
| Vertical | A stacked panel, one row per window with its reset time |
| Square | A ring gauge per product per window |

All layouts use the same usage data. The horizontal bar and the pole leave out the ↻ reset clocks, which are what
makes a row wide; they are in right-click → Details either way.

## About the month %
Claude and Codex have no monthly limit.
- **The estimate:** the month % is measured against your weekly limit × the weeks in your billing month. It uses this week's tokens (from ccusage) and weekly % to work out how many tokens 1% is.
- **Why "~":** it's an estimate, so it always has a "~" in front.

## What it costs to run
Nothing. `ccusage` runs `--offline` over logs already on this PC, and the 5h / 7d
percentages come from the same endpoints Claude Code and Codex already call with the tokens they already
hold - no extra account, no API key, no paid service. The widget never refreshes those tokens itself.

## Files
| File | Job |
|---|---|
| `lib/dashboard.ps1` | Usage cards, product filters and accessible action buttons |
| `widget.ps1` | The window, layouts, mouse and polling |
| `usage-json.js` | Collects everything below into one JSON for the widget |
| `lib/usage.js`, `lib/live.js`, `lib/claude.js`, `lib/codex.js`, `lib/window.js` | 5h / 7d limits (live API, with local fallbacks) |
| `lib/tokens.js` | Token counts from ccusage |
| `lib/billing.js` | Reads `billing.json` |
| `lib/month.js`, `lib/month.ps1` | Billing month and its % estimate; drawing the mo row |
| `lib/spotify.js`, `lib/spotify.ps1` | Spotify's Renews / Ends line |
| `lib/plan-status.ps1` | The green Renews / red Ends label |
| `lib/products.ps1` | Which products to show |
| `lib/pole.ps1` | The pole (stick) layout's rows |
| `lib/see-through.ps1` | See-through / click-through levels |
| `lib/theme.ps1` | Light / dark palettes, and following Windows |
| `lib/rounded.ps1` | The window's rounded corners and its edge |
| `lib/hover.ps1` | The chip under the hovered button, and the pointer shapes |
| `lib/compact.ps1` | Leaving the month row off the one-line bar |
| `lib/countdown.ps1` | "in 2h 14m" next to a reset time in Details |
| `lib/first-run.ps1` | The one-time note about the controls |
| `lib/alerts.ps1` | The tray warning at 80% and 95% |
| `lib/pace.ps1` | "At this rate" in Details: whether a window runs out before it resets |
| `lib/token-cache.js` | The 5-minute cache for the ccusage run |
| `statusline.js`, `lib/format.js` | The same usage in the Claude Code status line |
