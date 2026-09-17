# Warning you before you hit a limit, for widget.ps1 (dot-sourced; uses its $tray, $script:data and Is-Stale).
#
# A monitor you have to look at only helps when you look at it. The point of watching a limit is to hear about
# it before it stops you, so the tray icon says so once at 80% and once at 95%, for each product and each window.
#
# Nothing is fetched for this: it reads the numbers that just arrived. Right-click -> "Warn me near the limit"
# turns it off, remembered in ~\.claude\usage-widget-warn.txt.

$warnFile = Join-Path $env:USERPROFILE '.claude\usage-widget-warn.txt'
$alertFile = Join-Path $env:USERPROFILE '.claude\usage-widget-alerts.txt'
$ALERT_AT = 95, 80   # highest first: crossing straight past 80 to 95 warns once, at 95
$KEEP_KEYS = 40

$script:warnOn = -not (Test-Path $warnFile) -or (Get-Content $warnFile -Raw).Trim() -ne 'off'

# Which warnings have already been given, kept on disk so a restart doesn't repeat them. A key carries the
# window's reset time, so the next window is a clean slate without anything having to expire the file.
$script:fired = @{}
if (Test-Path $alertFile) {
  foreach ($line in (Get-Content $alertFile)) { if ($line) { $script:fired[$line] = $true } }
}

function Remember-Alert($key) {
  $script:fired[$key] = $true
  try { ($script:fired.Keys | Select-Object -Last $KEEP_KEYS) | Set-Content $alertFile } catch {}
}

function Set-Warn($on) {
  $script:warnOn = $on
  $warnItem.Checked = $on
  try { $(if ($on) { 'on' } else { 'off' }) | Set-Content $warnFile }  catch {}
}

# Called after every poll. Both products are checked whatever the widget is showing: a warning you didn't get
# because of a display setting is the worst kind.
function Check-Alerts {
  if (-not $script:warnOn -or -not $script:data) { return }
  foreach ($section in (Get-Sections $script:data 'both')) {
    $name, $usage, $month = $section
    # Out-of-date numbers are last-known, and a stale 95% would fire the moment the widget starts offline.
    if (-not $usage -or (Is-Stale $usage)) { continue }
    foreach ($w in @(@('session', $usage.fiveHour, 'fiveHour'), @('weekly', $usage.weekly, 'weekly'))) {
      Check-Window $name $w[0] $w[1] $w[2]
    }
  }
}

function Check-Window($name, $label, $win, $kind) {
  if (-not $win -or $null -eq $win.pct) { return }
  foreach ($level in $ALERT_AT) {
    if ($win.pct -lt $level) { continue }
    $key = "$name|$kind|$level|$($win.resetsAt)"
    if ($script:fired[$key]) { return }   # already warned at this level in this window
    Remember-Alert $key
    # Crossing straight to 95% also settles the 80% warning, so it can't arrive afterwards.
    foreach ($lower in $ALERT_AT) { if ($lower -lt $level) { Remember-Alert "$name|$kind|$lower|$($win.resetsAt)" } }
    $reset = Reset-Text $win.resetsAt ($kind -eq 'weekly')
    $tray.ShowBalloonTip(10000, "$name $label limit $($win.pct)% used", "It $reset.", 'Warning')
    return
  }
}
